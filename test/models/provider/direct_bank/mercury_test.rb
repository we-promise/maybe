require "test_helper"

class Provider::DirectBank::MercuryTest < ActiveSupport::TestCase
  setup do
    @valid_credentials = {
      access_token: "test_token",
      refresh_token: "refresh_token"
    }
    @provider = Provider::DirectBank::Mercury.new(@valid_credentials)
  end

  test "authentication_type returns oauth" do
    assert_equal :oauth, Provider::DirectBank::Mercury.authentication_type
  end

  test "validate_credentials returns true with valid token" do
    stub_request(:get, "https://api.mercury.com/api/v1/accounts")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(status: 200, body: { accounts: [] }.to_json)

    assert @provider.validate_credentials
  end

  test "validate_credentials returns false with invalid token" do
    stub_request(:get, "https://api.mercury.com/api/v1/accounts")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(status: 401)

    assert_not @provider.validate_credentials
  end

  test "get_accounts returns normalized account data" do
    mercury_accounts = {
      accounts: [
        {
          id: "acc_123",
          name: "Operating Account",
          kind: "checking",
          currentBalance: 10000.50,
          availableBalance: 9500.00,
          accountNumber: "****1234",
          routingNumber: "123456789"
        }
      ]
    }

    stub_request(:get, "https://api.mercury.com/api/v1/accounts")
      .to_return(status: 200, body: mercury_accounts.to_json)

    accounts = @provider.get_accounts

    assert_equal 1, accounts.length
    assert_equal "acc_123", accounts[0][:external_id]
    assert_equal "Operating Account", accounts[0][:name]
    assert_equal "checking", accounts[0][:account_type]
    assert_equal 10000.50, accounts[0][:current_balance]
  end

  test "get_transactions returns normalized transactions" do
    mercury_transactions = {
      transactions: [
        {
          id: "txn_456",
          amount: -150.00,
          postedAt: "2024-01-15",
          counterpartyName: "Office Supplies Inc",
          status: "completed",
          category: "Office"
        }
      ]
    }

    stub_request(:get, "https://api.mercury.com/api/v1/transactions")
      .with(query: hash_including("accountId" => "acc_123"))
      .to_return(status: 200, body: mercury_transactions.to_json)

    transactions = @provider.get_transactions("acc_123")

    assert_equal 1, transactions.length
    assert_equal "txn_456", transactions[0][:external_id]
    assert_equal 150.00, transactions[0][:amount]
    assert_equal Date.parse("2024-01-15"), transactions[0][:date]
  end

  test "get_balance returns current and available balance" do
    account_details = {
      id: "acc_123",
      currentBalance: 5000.00,
      availableBalance: 4500.00
    }

    stub_request(:get, "https://api.mercury.com/api/v1/accounts/acc_123")
      .to_return(status: 200, body: account_details.to_json)

    balance = @provider.get_balance("acc_123")

    assert_equal 5000.00, balance[:current]
    assert_equal 4500.00, balance[:available]
    assert_instance_of Time, balance[:as_of]
  end

  test "handles authentication errors properly" do
    stub_request(:get, "https://api.mercury.com/api/v1/accounts")
      .to_return(status: 401)

    assert_raises(Provider::DirectBank::Base::DirectBankError) do
      @provider.get_accounts
    end
  end

  test "refresh_access_token exchanges refresh token for new access token" do
    token_response = {
      access_token: "new_access_token",
      expires_in: 3600
    }

    ENV["MERCURY_CLIENT_ID"] = "test_client_id"
    ENV["MERCURY_CLIENT_SECRET"] = "test_client_secret"

    stub_request(:post, "https://api.mercury.com/api/v1/oauth/token")
      .with(body: hash_including("grant_type" => "refresh_token"))
      .to_return(status: 200, body: token_response.to_json)

    result = @provider.refresh_access_token

    assert_equal "new_access_token", result[:access_token]
    assert result[:expires_at] > Time.current
  ensure
    ENV.delete("MERCURY_CLIENT_ID")
    ENV.delete("MERCURY_CLIENT_SECRET")
  end
end
