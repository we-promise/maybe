class Provider::DirectBank::Mercury < Provider::DirectBank::Base
  base_uri "https://api.mercury.com/api/v1"
  headers "User-Agent" => "Sure Finance Mercury Client"
  default_options.merge!(verify: true, ssl_verify_mode: :peer)

  def self.authentication_type
    :oauth
  end

  def validate_credentials
    access_token = @credentials["access_token"] || @credentials[:access_token]
    return false unless access_token.present?

    response = self.class.get("/accounts", headers: auth_headers)
    response.code == 200
  rescue => e
    Rails.logger.error "Mercury credential validation failed: #{e.message}"
    false
  end

  def get_accounts
    response = self.class.get("/accounts", headers: auth_headers)
    data = parse_response(response)

    data[:accounts]&.map { |account| normalize_account(account) } || []
  end

  def get_transactions(account_id, start_date: nil, end_date: nil)
    params = {
      accountId: account_id,
      start: format_date(start_date || 30.days.ago),
      end: format_date(end_date || Date.current),
      limit: 1000
    }

    response = self.class.get("/transactions", query: params, headers: auth_headers)
    data = parse_response(response)

    data[:transactions]&.map { |transaction| normalize_transaction(transaction) } || []
  end

  def get_balance(account_id)
    response = self.class.get("/accounts/#{account_id}", headers: auth_headers)
    data = parse_response(response)

    {
      current: data[:currentBalance],
      available: data[:availableBalance],
      as_of: Time.current
    }
  end

  def get_account_details(account_id)
    response = self.class.get("/accounts/#{account_id}", headers: auth_headers)
    parse_response(response)
  end

  def refresh_access_token
    refresh_token = @credentials["refresh_token"] || @credentials[:refresh_token]
    return unless refresh_token.present?

    response = self.class.post("/oauth/token",
      body: {
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: ENV["MERCURY_CLIENT_ID"],
        client_secret: ENV["MERCURY_CLIENT_SECRET"]
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    if response.code == 200
      data = parse_response(response)
      {
        access_token: data[:access_token],
        refresh_token: data[:refresh_token] || refresh_token,
        expires_at: Time.current + (data[:expires_in] || 3600).seconds
      }
    else
      raise DirectBankError.new("Failed to refresh token", :authentication_failed)
    end
  end

  private

    def auth_headers
      {
        "Authorization" => "Bearer #{@credentials['access_token'] || @credentials[:access_token]}",
        "Content-Type" => "application/json"
      }
    end

    def normalize_account(raw_account)
      {
        external_id: raw_account[:id],
        name: raw_account[:name] || raw_account[:nickname] || "Mercury Account",
        currency: "USD",
        account_type: map_mercury_account_type(raw_account[:kind]),
        current_balance: raw_account[:currentBalance],
        available_balance: raw_account[:availableBalance],
        account_number_mask: raw_account[:accountNumber]&.last(4),
        routing_number: raw_account[:routingNumber],
        raw_data: raw_account
      }
    end

    def normalize_transaction(raw_transaction)
      {
        external_id: raw_transaction[:id],
        amount: parse_amount(raw_transaction[:amount]),
        date: Date.parse(raw_transaction[:postedAt] || raw_transaction[:createdAt]),
        description: build_description(raw_transaction),
        pending: raw_transaction[:status] == "pending",
        category: raw_transaction[:category],
        merchant_name: raw_transaction[:counterpartyName],
        raw_data: raw_transaction
      }
    end

    def map_mercury_account_type(kind)
      case kind&.downcase
      when "checking"
        "checking"
      when "savings", "treasury"
        "savings"
      else
        "checking"
      end
    end

    def parse_amount(amount)
      return 0 unless amount
      amount.to_f.abs
    end

    def build_description(transaction)
      if transaction[:note].present?
        transaction[:note]
      elsif transaction[:counterpartyName].present?
        transaction[:counterpartyName]
      else
        transaction[:description] || "Mercury Transaction"
      end
    end
end
