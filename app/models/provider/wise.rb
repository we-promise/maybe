class Provider::Wise
  include HTTParty

  base_uri "https://api.wise.com"
  headers "User-Agent" => "Sure Finance Wise Client"
  default_options.merge!(verify: true, ssl_verify_mode: :peer)

  def initialize(api_key)
    @api_key = api_key
  end

  def get_profiles
    response = self.class.get("/v1/profiles", headers: auth_headers)

    case response.code
    when 200
      JSON.parse(response.body, symbolize_names: true)
    when 401
      raise WiseError.new("Invalid API key", :authentication_failed)
    when 403
      raise WiseError.new("Access forbidden - check API key permissions", :access_forbidden)
    else
      raise WiseError.new("Failed to fetch profiles: #{response.code} #{response.message}", :fetch_failed)
    end
  end

  def get_accounts(profile_id)
    response = self.class.get("/v4/profiles/#{profile_id}/balances?types=STANDARD", headers: auth_headers)

    case response.code
    when 200
      JSON.parse(response.body, symbolize_names: true)
    when 401
      raise WiseError.new("Invalid API key", :authentication_failed)
    when 403
      raise WiseError.new("Access forbidden - check API key permissions", :access_forbidden)
    when 404
      raise WiseError.new("Profile not found", :profile_not_found)
    else
      raise WiseError.new("Failed to fetch accounts: #{response.code} #{response.message}", :fetch_failed)
    end
  end

  def get_transactions(profile_id, balance_id, start_date: nil, end_date: nil)
    # Wise expects ISO 8601 format for dates
    params = {
      currency: "USD", # This will be overridden by balance currency
      intervalStart: format_date(start_date || 30.days.ago),
      intervalEnd: format_date(end_date || Date.current)
    }

    response = self.class.get(
      "/v1/profiles/#{profile_id}/balance-statements/#{balance_id}/statement",
      query: params,
      headers: auth_headers
    )

    case response.code
    when 200
      JSON.parse(response.body, symbolize_names: true)
    when 401
      raise WiseError.new("Invalid API key", :authentication_failed)
    when 403
      raise WiseError.new("Access forbidden - check API key permissions", :access_forbidden)
    when 404
      raise WiseError.new("Balance not found", :balance_not_found)
    else
      raise WiseError.new("Failed to fetch transactions: #{response.code} #{response.message}", :fetch_failed)
    end
  end

  class WiseError < StandardError
    attr_reader :error_type

    def initialize(message, error_type = :unknown)
      super(message)
      @error_type = error_type
    end
  end

  private

    def auth_headers
      {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json"
      }
    end

    def format_date(date)
      date.to_datetime.iso8601
    end
end