require "test_helper"

class WiseItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = @user.family
    @wise_item = WiseItem.create!(
      family: @family,
      name: "Test Wise",
      api_key: "test_api_key"
    )
  end

  test "should get index" do
    get wise_items_url
    assert_response :success
    assert_select "h2", text: "Wise Connections"
  end

  test "should get new" do
    get new_wise_item_url
    assert_response :success
    assert_select "h2", text: "Connect Wise"
  end

  test "should show wise_item" do
    get wise_item_url(@wise_item)
    assert_response :success
    assert_select "h2", text: @wise_item.name
  end

  test "should create wise_item with valid api key" do
    Provider::Wise.any_instance.stubs(:get_profiles).returns([
      { id: 1, type: "personal", fullName: "John Doe" }
    ])

    assert_difference("WiseItem.count", 1) do
      post wise_items_url, params: {
        wise_item: { api_key: "new_api_key_123" }
      }
    end

    assert_redirected_to wise_items_url
    assert_equal "Wise connection added successfully! Your accounts will appear shortly as they sync in the background.", flash[:notice]
  end

  test "should not create wise_item with blank api key" do
    assert_no_difference("WiseItem.count") do
      post wise_items_url, params: {
        wise_item: { api_key: "" }
      }
    end

    assert_response :unprocessable_entity
    assert_equal "Please enter a Wise API key.", flash[:alert]
  end

  test "should handle invalid api key" do
    Provider::Wise.any_instance.stubs(:get_profiles).raises(
      Provider::Wise::WiseError.new("Invalid API key", :authentication_failed)
    )

    assert_no_difference("WiseItem.count") do
      post wise_items_url, params: {
        wise_item: { api_key: "invalid_key" }
      }
    end

    assert_response :unprocessable_entity
    assert_match /Invalid API key/, flash[:alert]
  end

  test "should destroy wise_item" do
    assert_difference("WiseItem.count", -1) do
      delete wise_item_url(@wise_item)
    end

    assert_redirected_to wise_items_url
    assert_equal "Wise connection will be removed", flash[:notice]
  end

  test "should trigger sync" do
    @wise_item.expects(:sync_later).once

    post sync_wise_item_url(@wise_item)

    assert_redirected_to wise_item_url(@wise_item)
    assert_equal "Sync started", flash[:notice]
  end

  test "should show setup accounts page" do
    wise_account = WiseAccount.create!(
      wise_item: @wise_item,
      account_id: "acc_123",
      name: "USD Account",
      currency: "USD",
      current_balance: 1000
    )

    get setup_accounts_wise_item_url(@wise_item)
    assert_response :success
    assert_select "h2", text: "Setup Your Wise Accounts"
  end

  test "should complete account setup" do
    wise_account = WiseAccount.create!(
      wise_item: @wise_item,
      account_id: "acc_123",
      name: "USD Account",
      currency: "USD",
      current_balance: 1000
    )

    assert_difference("Account.count", 1) do
      post complete_account_setup_wise_item_url(@wise_item), params: {
        account_types: { wise_account.id => "Depository" },
        account_subtypes: { wise_account.id => "checking" }
      }
    end

    assert_redirected_to wise_items_url
    assert_equal "Accounts have been set up successfully!", flash[:notice]

    @wise_item.reload
    assert_not @wise_item.pending_account_setup?

    account = Account.last
    assert_equal "USD Account", account.name
    assert_equal "USD", account.currency
    assert_equal 1000, account.balance
    assert_equal wise_account, account.wise_account
  end

  test "should skip accounts marked as Skip" do
    wise_account = WiseAccount.create!(
      wise_item: @wise_item,
      account_id: "acc_123",
      name: "USD Account",
      currency: "USD"
    )

    assert_no_difference("Account.count") do
      post complete_account_setup_wise_item_url(@wise_item), params: {
        account_types: { wise_account.id => "Skip" }
      }
    end

    assert_redirected_to wise_items_url
  end
end