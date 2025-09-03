# Detects and creates merchant records from SimpleFin transaction data
# SimpleFin provides clean payee data that works well for merchant identification
class SimplefinAccount::Transactions::MerchantDetector
  def initialize(transaction_data)
    @transaction_data = transaction_data.with_indifferent_access
  end

  def detect_merchant
    # SimpleFin provides clean payee data - use it directly
    payee = (transaction_data[:payee] || transaction_data["payee"])&.strip
    return nil unless payee.present?

    # Find or create merchant record using payee data
    ProviderMerchant.find_or_create_by!(
      source: "simplefin",
      name: payee
    ) do |merchant|
      merchant.provider_merchant_id = generate_merchant_id(payee)
    end
  end

  private
    attr_reader :transaction_data

    def generate_merchant_id(merchant_name)
      # Generate a consistent ID for merchants without explicit IDs
      "simplefin_#{Digest::MD5.hexdigest(merchant_name.downcase)}"
    end
end
