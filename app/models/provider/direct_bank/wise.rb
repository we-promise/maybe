class Provider::DirectBank::Wise < Provider::DirectBank::Base
  base_uri "https://api.wise.com"
  headers "User-Agent" => "Sure Finance Wise Client"
  default_options.merge!(verify: true, ssl_verify_mode: :peer)

  def self.authentication_type
    :api_key
  end

  def validate_credentials
    api_key = @credentials["api_key"] || @credentials[:api_key]
    return false unless api_key.present?

    response = self.class.get("/v1/profiles", headers: auth_headers)
    response.code == 200
  rescue => e
    Rails.logger.error "Wise credential validation failed: #{e.message}"
    false
  end

  def get_profiles
    response = self.class.get("/v1/profiles", headers: auth_headers)
    parse_response(response)
  end

  def get_accounts
    profiles = get_profiles
    all_accounts = []

    profiles.each do |profile|
      response = self.class.get("/v4/profiles/#{profile[:id]}/balances?types=STANDARD", headers: auth_headers)
      balances = parse_response(response)

      balances.each do |balance|
        all_accounts << normalize_wise_balance(balance, profile)
      end
    end

    all_accounts
  end

  def get_transactions(account_id, start_date: nil, end_date: nil, currency: "USD")
    parts = account_id.split("_")
    profile_id = parts[0]
    balance_id = parts[1]

    params = {
      currency: currency,
      intervalStart: format_wise_timestamp(start_date || 30.days.ago),
      intervalEnd: format_wise_timestamp(end_date || Date.current)
    }

    response = self.class.get(
      "/v1/profiles/#{profile_id}/balance-statements/#{balance_id}/statement",
      query: params,
      headers: auth_headers
    )

    data = parse_response(response)
    data[:transactions]&.map { |transaction| normalize_transaction(transaction) } || []
  end

  def get_balance(account_id)
    parts = account_id.split("_")
    profile_id = parts[0]
    balance_id = parts[1]

    response = self.class.get("/v4/profiles/#{profile_id}/balances/#{balance_id}", headers: auth_headers)
    balance = parse_response(response)

    {
      current: balance[:amount][:value],
      available: balance[:amount][:value],
      as_of: Time.current
    }
  end

  private

    def format_wise_timestamp(date)
      return nil if date.nil?
      date.to_time.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
    end

    def auth_headers
      {
        "Authorization" => "Bearer #{@credentials['api_key'] || @credentials[:api_key]}",
        "Content-Type" => "application/json"
      }
    end

    def normalize_wise_balance(balance, profile)
      {
        external_id: "#{profile[:id]}_#{balance[:id]}",
        name: "#{balance[:currency]} Balance",
        currency: balance[:currency],
        account_type: "checking",
        current_balance: balance[:amount][:value],
        available_balance: balance[:amount][:value],
        profile_type: profile[:type],
        profile_id: profile[:id],
        balance_id: balance[:id],
        raw_data: balance
      }
    end

    def normalize_transaction(raw_transaction)
      {
        external_id: raw_transaction[:referenceNumber],
        amount: raw_transaction[:amount][:value].abs,
        date: Date.parse(raw_transaction[:date]),
        description: raw_transaction[:description] || raw_transaction[:details][:description],
        pending: false,
        category: raw_transaction[:details][:type],
        raw_data: raw_transaction
      }
    end
end
