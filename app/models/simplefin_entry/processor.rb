class SimplefinEntry::Processor
  # simplefin_transaction is the raw hash fetched from SimpleFin API and converted to JSONB
  def initialize(simplefin_transaction, simplefin_account:)
    @simplefin_transaction = simplefin_transaction
    @simplefin_account = simplefin_account
  end

  def process
    SimplefinAccount.transaction do
      entry = account.entries.find_or_initialize_by(plaid_id: external_id) do |e|
        e.entryable = Transaction.new
      end

      entry.assign_attributes(
        amount: amount,
        currency: currency,
        date: date
      )

      entry.enrich_attribute(
        :name,
        name,
        source: "simplefin"
      )

      # SimpleFin provides no category data - categories will be set by AI or rules

      if merchant
        entry.transaction.enrich_attribute(
          :merchant_id,
          merchant.id,
          source: "simplefin"
        )
      end

      entry.save!
    end
  end

  private
    attr_reader :simplefin_transaction, :simplefin_account

    def account
      simplefin_account.account
    end

    def data
      @data ||= simplefin_transaction.with_indifferent_access
    end

    def external_id
      id = data[:id].presence
      raise ArgumentError, "SimpleFin transaction missing id: #{data.inspect}" unless id
      "simplefin_#{id}"
    end

    def name
      # Use SimpleFin's rich, clean data to create informative transaction names
      payee = data[:payee]
      description = data[:description]

      # Combine payee + description when both are present and different
      if payee.present? && description.present? && payee != description
        "#{payee} - #{description}"
      elsif payee.present?
        payee
      elsif description.present?
        description
      else
        data[:memo] || "Unknown transaction"
      end
    end

    def amount
      parsed_amount = case data[:amount]
      when String
        BigDecimal(data[:amount])
      when Numeric
        BigDecimal(data[:amount].to_s)
      else
        BigDecimal("0")
      end

      # SimpleFin uses banking convention (expenses negative, income positive)
      # Maybe expects opposite convention (expenses positive, income negative)
      # So we negate the amount to convert from SimpleFin to Maybe format
      -parsed_amount
    rescue ArgumentError => e
      Rails.logger.error "Failed to parse SimpleFin transaction amount: #{data[:amount].inspect} - #{e.message}"
      raise
    end

    def currency
      data[:currency] || account.currency
    end

    def date
      case data[:posted]
      when String
        Date.parse(data[:posted])
      when Integer, Float
        # Unix timestamp
        Time.at(data[:posted]).to_date
      when Time, DateTime
        data[:posted].to_date
      when Date
        data[:posted]
      else
        Rails.logger.error("SimpleFin transaction has invalid date value: #{data[:posted].inspect}")
        raise ArgumentError, "Invalid date format: #{data[:posted].inspect}"
      end
    rescue ArgumentError, TypeError => e
      Rails.logger.error("Failed to parse SimpleFin transaction date '#{data[:posted]}': #{e.message}")
      raise ArgumentError, "Unable to parse transaction date: #{data[:posted].inspect}"
    end


    def merchant
      @merchant ||= SimplefinAccount::Transactions::MerchantDetector.new(data).detect_merchant
    end
end
