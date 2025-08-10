class Provider::TwelveData < Provider
  include ExchangeRateConcept, SecurityConcept

  # Subclass so errors caught in this provider are raised as Provider::TwelveData::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)
  InvalidSecurityPriceError = Class.new(Error)

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      response = client.get("#{base_url}/api_usage")
      JSON.parse(response.body).dig("plan_category").present?
    end
  end

  def usage
    with_provider_response do
      response = client.get("#{base_url}/api_usage")

      parsed = JSON.parse(response.body)

      limit = parsed.dig("plan_daily_limit")
      used = parsed.dig("daily_usage")
      remaining = limit - used

      UsageData.new(
        used: used,
        limit: limit,
        utilization: used / limit * 100,
        plan: parsed.dig("plan_category"),
      )
    end
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      response = client.get("#{base_url}/exchange_rate") do |req|
        req.params["symbol"] = "#{from}/#{to}"
        req.params["date"] = date.to_s
      end

      rate = JSON.parse(response.body).dig("rate")

      Rate.new(date: date.to_date, from:, to:, rate: rate)
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      response = client.get("#{base_url}/time_series") do |req|
        req.params["symbol"] = "#{from}/#{to}"
        req.params["start_date"] = start_date.to_s
        req.params["end_date"] = end_date.to_s
        req.params["interval"] = "1day"
      end

      data = JSON.parse(response.body).dig("values")
      data.map do |resp|
        rate = resp.dig("close")
        date = resp.dig("datetime")
        if rate.nil?
          Rails.logger.warn("#{self.class.name} returned invalid rate data for pair from: #{from} to: #{to} on: #{date}.  Rate data: #{rate.inspect}")
          next
        end

        Rate.new(date: date.to_date, from:, to:, rate:)
      end.compact
    end
  end

  # ================================
  #           Securities
  # ================================

  def search_securities(symbol, country_code: nil, exchange_operating_mic: nil)
    with_provider_response do
      response = client.get("#{base_url}/symbol_search") do |req|
        req.params["symbol"] = symbol
        req.params["outputsize"] = 25
      end

      parsed = JSON.parse(response.body)

      parsed.dig("data").map do |security|
        country = ISO3166::Country.find_country_by_any_name(security.dig("country"))

        Security.new(
          symbol: security.dig("symbol"),
          name: security.dig("instrument_name"),
          logo_url: nil,
          exchange_operating_mic: security.dig("mic_code"),
          country_code: country ? country.alpha2 : nil
        )
      end
    end
  end

  def fetch_security_info(symbol:, exchange_operating_mic:)
    with_provider_response do
      response = client.get("#{base_url}/profile") do |req|
        req.params["symbol"] = symbol
        req.params["mic_code"] = exchange_operating_mic
      end

      profile = JSON.parse(response.body)

      response = client.get("#{base_url}/logo") do |req|
        req.params["symbol"] = symbol
        req.params["mic_code"] = exchange_operating_mic
      end

      logo = JSON.parse(response.body)

      SecurityInfo.new(
        symbol: symbol,
        name: profile.dig("name"),
        links: profile.dig("website"),
        logo_url: logo.dig("url"),
        description: profile.dig("description"),
        kind: profile.dig("type"),
        exchange_operating_mic: exchange_operating_mic
      )
    end
  end

  def fetch_security_price(symbol:, exchange_operating_mic: nil, date:)
    with_provider_response do
      historical_data = fetch_security_prices(symbol:, exchange_operating_mic:, start_date: date, end_date: date)

      raise ProviderError, "No prices found for security #{symbol} on date #{date}" if historical_data.data.empty?

      historical_data.data.first
    end
  end

  def fetch_security_prices(symbol:, exchange_operating_mic: nil, start_date:, end_date:)
    with_provider_response do
      response = client.get("#{base_url}/time_series") do |req|
        req.params["symbol"] = symbol
        req.params["mic_code"] = exchange_operating_mic
        req.params["start_date"] = start_date.to_s
        req.params["end_date"] = end_date.to_s
        req.params["interval"] = "1day"
      end

      parsed = JSON.parse(response.body)
      parsed.dig("values").map do |resp|
        price = resp.dig("close")
        date = resp.dig("datetime")
        if price.nil?
          Rails.logger.warn("#{self.class.name} returned invalid price data for security #{symbol} on: #{date}.  Price data: #{price.inspect}")
          next
        end

        Price.new(
          symbol: symbol,
          date: date.to_date,
          price: price,
          currency: parsed.dig("currency"),
          exchange_operating_mic: exchange_operating_mic
        )
      end.compact
    end
  end

  private
    attr_reader :api_key

    def base_url
      ENV["TWELVE_DATA_URL"] || "https://api.twelvedata.com"
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.request :json
        faraday.response :raise_error
        faraday.headers["Authorization"] = "apikey #{api_key}"
      end
    end
end
