require "test_helper"

class SimplefinItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
    @simplefin_item = SimplefinItem.create!(
      family: @family,
      name: "Test Connection",
      access_url: "https://example.com/test_access"
    )
  end

  test "should get index" do
    get simplefin_items_url
    assert_response :success
    assert_includes response.body, @simplefin_item.name
  end

  test "should get new" do
    get new_simplefin_item_url
    assert_response :success
  end

  test "should show simplefin item" do
    get simplefin_item_url(@simplefin_item)
    assert_response :success
  end

  test "should destroy simplefin item" do
    assert_difference("SimplefinItem.count", 0) do # doesn't actually delete immediately
      delete simplefin_item_url(@simplefin_item)
    end

    assert_redirected_to accounts_path
    @simplefin_item.reload
    assert @simplefin_item.scheduled_for_deletion?
  end

  test "should sync simplefin item" do
    post sync_simplefin_item_url(@simplefin_item)
    assert_redirected_to accounts_path
  end

  test "should get edit" do
    @simplefin_item.update!(status: :requires_update)
    get edit_simplefin_item_url(@simplefin_item)
    assert_response :success
  end

  test "should update simplefin item with valid token" do
    @simplefin_item.update!(status: :requires_update)

    # Mock the SimpleFin provider to prevent real API calls
    mock_provider = mock()
    mock_provider.expects(:claim_access_url).with("valid_token").returns("https://example.com/new_access")
    mock_provider.expects(:get_accounts).returns({ accounts: [] }).at_least_once
    Provider::Simplefin.expects(:new).returns(mock_provider).at_least_once

    # Let the real create_simplefin_item! method run - don't mock it

    patch simplefin_item_url(@simplefin_item), params: {
      simplefin_item: { setup_token: "valid_token" }
    }

    assert_redirected_to accounts_path
    assert_match(/updated successfully/, flash[:notice])
    @simplefin_item.reload
    assert @simplefin_item.scheduled_for_deletion?
  end

  test "should handle update with invalid token" do
    @simplefin_item.update!(status: :requires_update)

    patch simplefin_item_url(@simplefin_item), params: {
      simplefin_item: { setup_token: "" }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Please enter a SimpleFin setup token"
  end

  test "should transfer accounts when updating simplefin item token" do
    @simplefin_item.update!(status: :requires_update)

    # Create old SimpleFin accounts linked to Maybe accounts
    old_simplefin_account1 = @simplefin_item.simplefin_accounts.create!(
      name: "Test Checking",
      account_id: "sf_account_123",
      currency: "USD",
      current_balance: 1000,
      account_type: "depository"
    )
    old_simplefin_account2 = @simplefin_item.simplefin_accounts.create!(
      name: "Test Savings",
      account_id: "sf_account_456",
      currency: "USD",
      current_balance: 5000,
      account_type: "depository"
    )

    # Create Maybe accounts linked to the SimpleFin accounts
    maybe_account1 = Account.create!(
      family: @family,
      name: "Checking Account",
      balance: 1000,
      currency: "USD",
      accountable_type: "Depository",
      accountable: Depository.create!(subtype: "checking"),
      simplefin_account_id: old_simplefin_account1.id
    )
    maybe_account2 = Account.create!(
      family: @family,
      name: "Savings Account",
      balance: 5000,
      currency: "USD",
      accountable_type: "Depository",
      accountable: Depository.create!(subtype: "savings"),
      simplefin_account_id: old_simplefin_account2.id
    )

    # Update old SimpleFin accounts to reference the Maybe accounts
    old_simplefin_account1.update!(account: maybe_account1)
    old_simplefin_account2.update!(account: maybe_account2)

    # Mock only the external API calls, let business logic run
    mock_provider = mock()
    mock_provider.expects(:claim_access_url).with("valid_token").returns("https://example.com/new_access")
    mock_provider.expects(:get_accounts).returns({
      accounts: [
        {
          id: "sf_account_123",
          name: "Test Checking",
          type: "depository",
          currency: "USD",
          balance: 1000,
          transactions: []
        },
        {
          id: "sf_account_456",
          name: "Test Savings",
          type: "depository",
          currency: "USD",
          balance: 5000,
          transactions: []
        }
      ]
    }).at_least_once
    Provider::Simplefin.expects(:new).returns(mock_provider).at_least_once

    # Perform the update
    patch simplefin_item_url(@simplefin_item), params: {
      simplefin_item: { setup_token: "valid_token" }
    }

    assert_redirected_to accounts_path
    assert_match(/updated successfully/, flash[:notice])

    # Verify accounts were transferred to new SimpleFin accounts
    assert Account.exists?(maybe_account1.id), "maybe_account1 should still exist"
    assert Account.exists?(maybe_account2.id), "maybe_account2 should still exist"

    maybe_account1.reload
    maybe_account2.reload

    # Find the new SimpleFin item that was created
    new_simplefin_item = @family.simplefin_items.where.not(id: @simplefin_item.id).first
    assert_not_nil new_simplefin_item, "New SimpleFin item should have been created"

    new_sf_account1 = new_simplefin_item.simplefin_accounts.find_by(account_id: "sf_account_123")
    new_sf_account2 = new_simplefin_item.simplefin_accounts.find_by(account_id: "sf_account_456")

    assert_not_nil new_sf_account1, "New SimpleFin account with ID sf_account_123 should exist"
    assert_not_nil new_sf_account2, "New SimpleFin account with ID sf_account_456 should exist"

    assert_equal new_sf_account1.id, maybe_account1.simplefin_account_id
    assert_equal new_sf_account2.id, maybe_account2.simplefin_account_id

    # Verify old SimpleFin accounts no longer reference Maybe accounts
    old_simplefin_account1.reload
    old_simplefin_account2.reload
    assert_nil old_simplefin_account1.account
    assert_nil old_simplefin_account2.account

    # Verify old SimpleFin item is scheduled for deletion
    @simplefin_item.reload
    assert @simplefin_item.scheduled_for_deletion?
  end

  test "should handle partial account matching during token update" do
    @simplefin_item.update!(status: :requires_update)

    # Create old SimpleFin account
    old_simplefin_account = @simplefin_item.simplefin_accounts.create!(
      name: "Test Checking",
      account_id: "sf_account_123",
      currency: "USD",
      current_balance: 1000,
      account_type: "depository"
    )

    # Create Maybe account linked to the SimpleFin account
    maybe_account = Account.create!(
      family: @family,
      name: "Checking Account",
      balance: 1000,
      currency: "USD",
      accountable_type: "Depository",
      accountable: Depository.create!(subtype: "checking"),
      simplefin_account_id: old_simplefin_account.id
    )
    old_simplefin_account.update!(account: maybe_account)

    # Mock only the external API calls, let business logic run
    mock_provider = mock()
    mock_provider.expects(:claim_access_url).with("valid_token").returns("https://example.com/new_access")
    # Return empty accounts list to simulate account was removed from bank
    mock_provider.expects(:get_accounts).returns({ accounts: [] }).at_least_once
    Provider::Simplefin.expects(:new).returns(mock_provider).at_least_once

    # Perform update
    patch simplefin_item_url(@simplefin_item), params: {
      simplefin_item: { setup_token: "valid_token" }
    }

    assert_redirected_to accounts_path

    # Verify Maybe account still linked to old SimpleFin account (no transfer occurred)
    maybe_account.reload
    old_simplefin_account.reload
    assert_equal old_simplefin_account.id, maybe_account.simplefin_account_id
    assert_equal maybe_account, old_simplefin_account.account

    # Old item still scheduled for deletion
    @simplefin_item.reload
    assert @simplefin_item.scheduled_for_deletion?
  end
end
