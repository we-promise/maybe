require "test_helper"

class WiseItemTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @wise_item = WiseItem.create!(
      family: @family,
      name: "Test Wise Account",
      api_key: "test_api_key_123"
    )
  end

  test "should be valid with required attributes" do
    assert @wise_item.valid?
  end

  test "should require name" do
    @wise_item.name = nil
    assert_not @wise_item.valid?
    assert_includes @wise_item.errors[:name], "can't be blank"
  end

  test "should require api_key" do
    @wise_item.api_key = nil
    assert_not @wise_item.valid?
    assert_includes @wise_item.errors[:api_key], "can't be blank"
  end

  test "should belong to family" do
    assert_equal @family, @wise_item.family
  end

  test "should have many wise_accounts" do
    assert_respond_to @wise_item, :wise_accounts
  end

  test "should have many accounts through wise_accounts" do
    assert_respond_to @wise_item, :accounts
  end

  test "should encrypt api_key if encryption is configured" do
    if Rails.application.credentials.active_record_encryption.present?
      # API key should be encrypted in database
      raw_value = WiseItem.connection.execute(
        "SELECT api_key FROM wise_items WHERE id = '#{@wise_item.id}'"
      ).first["api_key"]

      assert_not_equal "test_api_key_123", raw_value
      assert_equal "test_api_key_123", @wise_item.api_key
    else
      # When encryption is not configured, API key should be stored as plain text
      assert_equal "test_api_key_123", @wise_item.api_key
    end
  end

  test "should be syncable" do
    assert_respond_to @wise_item, :sync_later
    assert_respond_to @wise_item, :syncing?
  end

  test "should create wise_provider with api_key" do
    provider = @wise_item.wise_provider
    assert_instance_of Provider::Wise, provider
  end

  test "should track pending_account_setup" do
    assert_not @wise_item.pending_account_setup?
    @wise_item.update!(pending_account_setup: true)
    assert @wise_item.pending_account_setup?
  end

  test "should destroy associated wise_accounts when destroyed" do
    wise_account = WiseAccount.create!(
      wise_item: @wise_item,
      account_id: "test_123",
      name: "Test Account",
      currency: "USD"
    )

    assert_difference "WiseAccount.count", -1 do
      @wise_item.destroy
    end
  end
end
