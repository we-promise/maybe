require "test_helper"

class FetchAccountsBalanceToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    Current.session = @user.sessions.create!
  end

  test "fetches all account balances" do
    tool = FetchAccountsBalanceTool.new
    result = tool.call

    assert_equal @family.accounts.count, result[:accounts].size
    assert result[:total_balance].positive?
  end

  test "filters by account type" do
    tool = FetchAccountsBalanceTool.new
    result = tool.call(account_type: "Depository")

    assert result[:accounts].all? { |a| a[:type] == "Depository" }
  end
end
