require "test_helper"

class MercuryConnectionTest < ActiveSupport::TestCase
  setup do
    @family = families(:main)
    @valid_credentials = {
      "access_token" => "test_access_token",
      "refresh_token" => "test_refresh_token",
      "expires_at" => 1.hour.from_now.iso8601
    }
  end

  test "creates mercury connection with valid credentials" do
    connection = MercuryConnection.new(
      family: @family,
      name: "Mercury Test",
      credentials: @valid_credentials
    )

    assert connection.valid?
    assert_equal "Mercury", connection.provider_type
  end

  test "requires access token in credentials" do
    connection = MercuryConnection.new(
      family: @family,
      name: "Mercury Test",
      credentials: { "refresh_token" => "test" }
    )

    assert_not connection.valid?
    assert_includes connection.errors[:credentials], "must include access token"
  end

  test "identifies when token is expired" do
    expired_credentials = @valid_credentials.merge(
      "expires_at" => 1.hour.ago.iso8601
    )

    connection = MercuryConnection.create!(
      family: @family,
      name: "Mercury Test",
      credentials: expired_credentials
    )

    assert connection.send(:token_expired?)
  end

  test "identifies when token is not expired" do
    connection = MercuryConnection.create!(
      family: @family,
      name: "Mercury Test",
      credentials: @valid_credentials
    )

    assert_not connection.send(:token_expired?)
  end

  test "provider returns Mercury provider instance" do
    connection = MercuryConnection.create!(
      family: @family,
      name: "Mercury Test",
      credentials: @valid_credentials
    )

    assert_instance_of Provider::DirectBank::Mercury, connection.provider
  end

  test "refresh_token_if_needed! updates credentials when token expired" do
    expired_credentials = @valid_credentials.merge(
      "expires_at" => 1.hour.ago.iso8601
    )

    connection = MercuryConnection.create!(
      family: @family,
      name: "Mercury Test",
      credentials: expired_credentials
    )

    new_token_data = {
      access_token: "new_access_token",
      expires_at: 1.hour.from_now
    }

    Provider::DirectBank::Mercury.any_instance.expects(:refresh_access_token).returns(new_token_data)

    connection.refresh_token_if_needed!

    assert_equal "new_access_token", connection.reload.credentials["access_token"]
  end
end
