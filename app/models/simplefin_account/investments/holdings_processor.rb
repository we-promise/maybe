class SimplefinAccount::Investments::HoldingsProcessor
  def initialize(simplefin_account)
    @simplefin_account = simplefin_account
  end

  def process
    return if holdings_data.empty?
    return unless account&.accountable_type == "Investment"

    holdings_data.each do |simplefin_holding|
      begin
        symbol = simplefin_holding["symbol"]
        next unless symbol.present?

        security = resolve_security(symbol, simplefin_holding["description"])
        next unless security.present?

        # Use the created timestamp as the holding date, fallback to current date
        holding_date = parse_holding_date(simplefin_holding["created"]) || Date.current

        holding = account.holdings.find_or_initialize_by(
          security: security,
          date: holding_date,
          currency: simplefin_holding["currency"] || "USD"
        )

        # Parse shares quantity
        qty = parse_decimal(simplefin_holding["shares"])
        # Use current market_value for price calculation if we have shares
        price = if qty > 0
          parse_decimal(simplefin_holding["market_value"]) / qty
        else
          parse_decimal(simplefin_holding["purchase_price"]) || 0
        end

        holding.assign_attributes(
          qty: qty,
          price: price,
          amount: parse_decimal(simplefin_holding["market_value"]) || 0
        )

        ActiveRecord::Base.transaction do
          holding.save!

          # Delete all holdings for this security after the holding date
          # This ensures we don't have stale holdings data
          account.holdings
            .where(security: security)
            .where("date > ?", holding_date)
            .destroy_all
        end
      rescue => e
        Rails.logger.error "Error processing SimpleFin holding #{symbol}: #{e.message}"
      end
    end
  end

  private
    attr_reader :simplefin_account

    def account
      simplefin_account.account
    end

    def holdings_data
      # Holdings should be in the account's raw_payload, not the item's payload
      return [] unless simplefin_account.raw_payload
      simplefin_account.raw_payload["holdings"] || simplefin_account.raw_payload[:holdings] || []
    end

    def resolve_security(symbol, description)
      # Use Security::Resolver to find or create the security
      Security::Resolver.new(symbol).resolve
    rescue ArgumentError => e
      Rails.logger.error "Failed to resolve SimpleFin security #{symbol}: #{e.message}"
      nil
    end

    def parse_holding_date(created_timestamp)
      return nil unless created_timestamp

      case created_timestamp
      when Integer
        Time.at(created_timestamp).to_date
      when String
        Date.parse(created_timestamp)
      else
        nil
      end
    rescue ArgumentError => e
      Rails.logger.error "Failed to parse SimpleFin holding date #{created_timestamp}: #{e.message}"
      nil
    end

    def parse_decimal(value)
      return 0 unless value.present?

      case value
      when String
        BigDecimal(value)
      when Numeric
        BigDecimal(value.to_s)
      else
        BigDecimal("0")
      end
    rescue ArgumentError => e
      Rails.logger.error "Failed to parse SimpleFin decimal value #{value}: #{e.message}"
      BigDecimal("0")
    end
end
