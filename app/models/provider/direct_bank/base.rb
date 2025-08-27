class Provider::DirectBank::Base
  include HTTParty

  class DirectBankError < StandardError
    attr_reader :error_type

    def initialize(message, error_type = :unknown)
      super(message)
      @error_type = error_type
    end
  end

  def initialize(credentials)
    @credentials = credentials
  end

  def self.authentication_type
    raise NotImplementedError, "Subclasses must implement authentication_type"
  end

  def validate_credentials
    raise NotImplementedError, "Subclasses must implement validate_credentials"
  end

  def get_accounts
    raise NotImplementedError, "Subclasses must implement get_accounts"
  end

  def get_transactions(account_id, start_date: nil, end_date: nil)
    raise NotImplementedError, "Subclasses must implement get_transactions"
  end

  def get_balance(account_id)
    raise NotImplementedError, "Subclasses must implement get_balance"
  end

  def supported_account_types
    %w[checking savings]
  end

  def supports_oauth?
    self.class.authentication_type == :oauth
  end

  def supports_api_key?
    self.class.authentication_type == :api_key
  end

  protected

    def format_date(date)
      return nil if date.nil?
      date.to_date.iso8601
    end

    def parse_response(response, success_codes: [ 200 ])
      unless success_codes.include?(response.code)
        handle_error_response(response)
      end

      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError => e
      raise DirectBankError.new("Invalid response format: #{e.message}", :parse_error)
    end

    def handle_error_response(response)
      error_body = response.body rescue ""
      Rails.logger.error "API Error #{response.code}: #{error_body[0..500]}"

      case response.code
      when 401
        raise DirectBankError.new("Authentication failed", :authentication_failed)
      when 403
        raise DirectBankError.new("Access forbidden", :access_forbidden)
      when 404
        raise DirectBankError.new("Resource not found", :not_found)
      when 429
        raise DirectBankError.new("Rate limit exceeded", :rate_limited)
      when 500..599
        raise DirectBankError.new("Server error: #{response.code}", :server_error)
      else
        raise DirectBankError.new("Request failed: #{response.code} #{response.message}", :request_failed)
      end
    end

    def normalize_account(raw_account)
      {
        external_id: raw_account[:id] || raw_account[:account_id],
        name: raw_account[:name] || "Account",
        currency: raw_account[:currency] || "USD",
        account_type: map_account_type(raw_account),
        current_balance: raw_account[:balance] || raw_account[:current_balance],
        available_balance: raw_account[:available_balance],
        raw_data: raw_account
      }
    end

    def normalize_transaction(raw_transaction)
      {
        external_id: raw_transaction[:id] || raw_transaction[:transaction_id],
        amount: raw_transaction[:amount],
        date: parse_transaction_date(raw_transaction),
        description: raw_transaction[:description] || raw_transaction[:name],
        pending: raw_transaction[:pending] || false,
        category: raw_transaction[:category],
        raw_data: raw_transaction
      }
    end

  private

    def map_account_type(raw_account)
      "checking"
    end

    def parse_transaction_date(raw_transaction)
      date_string = raw_transaction[:date] || raw_transaction[:posted_date]
      Date.parse(date_string) if date_string
    rescue
      Date.current
    end
end
