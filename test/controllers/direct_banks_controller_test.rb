require "test_helper"

class DirectBanksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:main)
    @family = families(:main)
  end

  test "index displays mercury connections" do
    get direct_bank_mercury_index_path

    assert_response :success
    assert_select "h1", "Mercury Connections"
  end

  test "new displays mercury connection form" do
    get new_direct_bank_mercury_path

    assert_response :success
    assert_select "h1", "Connect Mercury"
    assert_select "input[type=hidden][name=oauth_flow]"
  end

  test "new displays wise connection form with api key field" do
    get new_direct_bank_wise_path

    assert_response :success
    assert_select "h1", "Connect Wise"
    assert_select "input[type=password][name=api_key]"
  end

  test "create creates mercury connection with valid oauth credentials" do
    Provider::DirectBank::Mercury.any_instance.expects(:validate_credentials).returns(true)

    assert_difference "MercuryConnection.count" do
      post direct_banks_path(:mercury), params: {
        access_token: "valid_token",
        refresh_token: "refresh_token",
        expires_at: 1.hour.from_now.iso8601
      }
    end

    assert_redirected_to direct_bank_path(:mercury, MercuryConnection.last)
    assert_equal "Mercury connection added successfully! Your accounts will appear shortly.", flash[:notice]
  end

  test "create creates wise connection with valid api key" do
    Provider::DirectBank::Wise.any_instance.expects(:validate_credentials).returns(true)

    assert_difference "WiseConnection.count" do
      post direct_banks_path(:wise), params: {
        api_key: "valid_api_key"
      }
    end

    assert_redirected_to direct_bank_path(:wise, WiseConnection.last)
  end

  test "create renders new with error for invalid credentials" do
    Provider::DirectBank::Mercury.any_instance.expects(:validate_credentials)
      .raises(Provider::DirectBank::Base::DirectBankError.new("Invalid token", :authentication_failed))

    assert_no_difference "MercuryConnection.count" do
      post direct_banks_path(:mercury), params: {
        access_token: "invalid_token"
      }
    end

    assert_response :success
    assert_select "div.bg-red-50", /Authentication failed/
  end

  test "show displays connection details" do
    connection = MercuryConnection.create!(
      family: @family,
      name: "Test Mercury",
      credentials: { access_token: "test" }
    )

    get direct_bank_path(:mercury, connection)

    assert_response :success
    assert_select "h1", "Test Mercury"
  end

  test "destroy schedules connection for deletion" do
    connection = MercuryConnection.create!(
      family: @family,
      name: "Test Mercury",
      credentials: { access_token: "test" }
    )

    assert_enqueued_with(job: DestroyJob) do
      delete direct_bank_path(:mercury, connection)
    end

    assert_redirected_to direct_bank_mercury_index_path
    assert connection.reload.scheduled_for_deletion?
  end

  test "sync triggers connection sync" do
    connection = MercuryConnection.create!(
      family: @family,
      name: "Test Mercury",
      credentials: { access_token: "test" }
    )

    MercuryConnection.any_instance.expects(:sync_later)

    post sync_direct_bank_path(:mercury, connection)

    assert_redirected_to direct_bank_path(:mercury, connection)
    assert_equal "Sync started", flash[:notice]
  end

  test "setup_accounts displays unconnected accounts" do
    connection = MercuryConnection.create!(
      family: @family,
      name: "Test Mercury",
      credentials: { access_token: "test" }
    )

    account = MercuryAccount.create!(
      direct_bank_connection: connection,
      external_id: "acc_123",
      name: "Test Account",
      currency: "USD",
      current_balance: 1000
    )

    get setup_accounts_direct_bank_path(:mercury, connection)

    assert_response :success
    assert_select "h1", "Set Up Your Accounts"
    assert_select "h3", "Test Account"
  end

  test "complete_account_setup creates accounts and links them" do
    connection = MercuryConnection.create!(
      family: @family,
      name: "Test Mercury",
      credentials: { access_token: "test" },
      pending_account_setup: true
    )

    bank_account = MercuryAccount.create!(
      direct_bank_connection: connection,
      external_id: "acc_123",
      name: "Test Account",
      currency: "USD",
      current_balance: 1000
    )

    assert_difference "Account.count" do
      post complete_account_setup_direct_bank_path(:mercury, connection), params: {
        accounts: {
          bank_account.id => {
            account_type: "Depository",
            subtype: "checking",
            balance: "1000"
          }
        }
      }
    end

    assert_redirected_to accounts_path
    assert bank_account.reload.connected?
    assert_not connection.reload.pending_account_setup?
  end
end
