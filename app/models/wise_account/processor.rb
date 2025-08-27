class WiseAccount::Processor
  attr_reader :wise_account

  def initialize(wise_account)
    @wise_account = wise_account
  end

  def process
    ensure_account_exists
    process_transactions
  end

  private

    def ensure_account_exists
      return if wise_account.account.present?

      # This should not happen in normal flow since accounts are created manually
      # during setup, but keeping as safety check
      Rails.logger.error("Wise account #{wise_account.id} has no associated Account - this should not happen after manual setup")
    end

    def process_transactions
      return unless wise_account.raw_transactions_payload.present?

      account = wise_account.account
      transactions_data = wise_account.raw_transactions_payload

      transactions_data.each do |transaction_data|
        process_transaction(account, transaction_data)
      end
    end

    def process_transaction(account, transaction_data)
      # Handle both string and symbol keys
      data = transaction_data.with_indifferent_access

      # Convert Wise transaction to internal Transaction format
      amount = parse_amount(data[:amount], account.currency)
      posted_date = parse_date(data[:date])

      # Use a unique external ID for Wise transactions
      external_id = "wise_#{data[:referenceNumber] || data[:id]}"

      # Check if entry already exists
      existing_entry = Entry.find_by(plaid_id: external_id)

      unless existing_entry
        # Create the transaction (entryable)
        transaction = Transaction.new(
          external_id: external_id
        )

        # Create the entry with the transaction
        Entry.create!(
          account: account,
          name: build_transaction_name(data),
          amount: amount,
          date: posted_date,
          currency: account.currency,
          entryable: transaction,
          plaid_id: external_id
        )
      end
    rescue => e
      Rails.logger.error("Failed to process Wise transaction #{data[:id]}: #{e.message}")
      # Don't fail the entire sync for one bad transaction
    end

    def build_transaction_name(data)
      # Try different fields that might contain the description
      data[:details]&.dig(:description) ||
        data[:details]&.dig(:merchant)&.dig(:name) ||
        data[:details]&.dig(:paymentReference) ||
        data[:exchangeDetails]&.dig(:description) ||
        data[:type] ||
        "Wise transaction"
    end

    def parse_amount(amount_data, currency)
      parsed_amount = case amount_data
      when Hash
        # Wise returns amount as { value: 123.45, currency: "USD" }
        BigDecimal(amount_data[:value].to_s)
      when String
        BigDecimal(amount_data)
      when Numeric
        BigDecimal(amount_data.to_s)
      else
        BigDecimal("0")
      end

      # Wise uses banking convention (expenses negative, income positive)
      # Maybe expects opposite convention (expenses positive, income negative)
      # So we negate the amount to convert from Wise to Maybe format
      -parsed_amount
    rescue ArgumentError => e
      Rails.logger.error "Failed to parse Wise transaction amount: #{amount_data.inspect} - #{e.message}"
      BigDecimal("0")
    end

    def parse_date(date_value)
      case date_value
      when String
        # Wise typically returns ISO 8601 format
        DateTime.parse(date_value).to_date
      when Integer, Float
        # Unix timestamp
        Time.at(date_value).to_date
      when Time, DateTime
        date_value.to_date
      when Date
        date_value
      else
        Rails.logger.error("Wise transaction has invalid date value: #{date_value.inspect}")
        raise ArgumentError, "Invalid date format: #{date_value.inspect}"
      end
    rescue ArgumentError, TypeError => e
      Rails.logger.error("Failed to parse Wise transaction date '#{date_value}': #{e.message}")
      raise ArgumentError, "Unable to parse transaction date: #{date_value.inspect}"
    end
end
