require "test_helper"

class WiseAccountTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @wise_item = WiseItem.create!(
      family: @family,
      name: "Test Wise",
      api_key: "test_key"
    )
    @wise_account = WiseAccount.create!(
      wise_item: @wise_item,
      account_id: "acc_123",
      name: "USD Account",
      currency: "USD"
    )
  end

  test "should be valid with required attributes" do
    assert @wise_account.valid?
  end

  test "should require account_id" do
    @wise_account.account_id = nil
    assert_not @wise_account.valid?
    assert_includes @wise_account.errors[:account_id], "can't be blank"
  end

  test "should belong to wise_item" do
    assert_equal @wise_item, @wise_account.wise_item
  end

  test "should have unique account_id per wise_item" do
    duplicate = @wise_item.wise_accounts.build(
      account_id: @wise_account.account_id,
      name: "Another Account"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:account_id], "has already been taken"
  end

  test "should allow same account_id for different wise_items" do
    other_item = WiseItem.create!(
      family: @family,
      name: "Other Wise",
      api_key: "other_key"
    )
    other_account = other_item.wise_accounts.build(
      account_id: @wise_account.account_id,
      name: "Other Account"
    )
    assert other_account.valid?
  end

  test "upsert_wise_snapshot! should update account data" do
    snapshot = {
      id: 123,
      amount: { value: 1000.50, currency: "EUR" },
      name: "Euro Account"
    }

    @wise_account.upsert_wise_snapshot!(snapshot)

    assert_equal "Euro Account", @wise_account.name
    assert_equal "EUR", @wise_account.currency
    assert_equal 1000.50, @wise_account.current_balance
    assert_equal 1000.50, @wise_account.available_balance
    assert_equal snapshot, @wise_account.raw_payload.deep_symbolize_keys
  end

  test "should nullify account association when destroyed" do
    account = Account.create!(
      family: @family,
      name: "Test Account",
      balance: 100,
      currency: "USD",
      wise_account: @wise_account,
      accountable: Depository.new
    )

    @wise_account.destroy
    account.reload

    assert_nil account.wise_account_id
  end
end
