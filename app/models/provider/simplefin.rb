class Provider::Simplefin
  include HTTParty

  headers "User-Agent" => "Sure Finance SimpleFin Client"
  default_options.merge!(verify: true, ssl_verify_mode: OpenSSL::SSL::VERIFY_PEER, timeout: 120)

  def initialize
  end

  def claim_access_url(setup_token)
    # Decode the base64 setup token to get the claim URL
    claim_url = Base64.decode64(setup_token)

    response = HTTParty.post(claim_url)

    case response.code
    when 200
      # The response body contains the access URL with embedded credentials
      response.body.strip
    when 403
      raise SimplefinError.new("Setup token may be compromised, expired, or already used", :token_compromised)
    else
      raise SimplefinError.new("Failed to claim access URL: #{response.code} #{response.message}", :claim_failed)
    end
  end

  def get_accounts(access_url, start_date: nil, end_date: nil, pending: nil)
    # Build query parameters
    query_params = {}

    # SimpleFin expects Unix timestamps for dates
    if start_date
      start_timestamp = start_date.to_time.to_i
      query_params["start-date"] = start_timestamp.to_s
    end

    if end_date
      end_timestamp = end_date.to_time.to_i
      query_params["end-date"] = end_timestamp.to_s
    end

    query_params["pending"] = pending ? "1" : "0" unless pending.nil?

    accounts_url = "#{access_url}/accounts"
    accounts_url += "?#{URI.encode_www_form(query_params)}" unless query_params.empty?


    # The access URL already contains HTTP Basic Auth credentials
    begin
      response = HTTParty.get(accounts_url)
    rescue SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error "SimpleFin API: GET /accounts failed: #{e.class}: #{e.message}"
      raise SimplefinError.new("Exception during GET request: #{e.message}", :request_failed)
    rescue => e
      Rails.logger.error "SimpleFin API: Unexpected error during GET /accounts: #{e.class}: #{e.message}"
      raise SimplefinError.new("Exception during GET request: #{e.message}", :request_failed)
    end


    case response.code
    when 200
      JSON.parse(response.body, symbolize_names: true)
    when 400
      Rails.logger.error "SimpleFin API: Bad request - #{response.body}"
      raise SimplefinError.new("Bad request to SimpleFin API: #{response.body}", :bad_request)
    when 403
      raise SimplefinError.new("Access URL is no longer valid", :access_forbidden)
    when 402
      raise SimplefinError.new("Payment required to access this account", :payment_required)
    else
      Rails.logger.error "SimpleFin API: Unexpected response - Code: #{response.code}, Body: #{response.body}"
      raise SimplefinError.new("Failed to fetch accounts: #{response.code} #{response.message} - #{response.body}", :fetch_failed)
    end
  end

  def get_info(base_url)
    response = HTTParty.get("#{base_url}/info")

    case response.code
    when 200
      response.body.strip.split("\n")
    else
      raise SimplefinError.new("Failed to get server info: #{response.code} #{response.message}", :info_failed)
    end
  end

  class SimplefinError < StandardError
    attr_reader :error_type

    def initialize(message, error_type = :unknown)
      super(message)
      @error_type = error_type
    end
  end
end
