class Provider::Openrouter::AutoMerchantDetector
  DEFAULT_MODEL = "openai/gpt-4o-mini"

  def initialize(client, model: "", transactions:, user_merchants:)
    @client = client
    @model = model
    @transactions = transactions
    @user_merchants = user_merchants
  end

  def auto_detect_merchants
    response = client.responses.create(parameters: {
      model: model.presence || DEFAULT_MODEL,
      input: [ { role: "developer", content: developer_message } ],
      text: {
        format: {
          type: "json_schema",
          name: "auto_detect_personal_finance_merchants",
          strict: true,
          schema: json_schema
        }
      },
      instructions: instructions
    })

    Rails.logger.info("Tokens used to auto-detect merchants: #{response.dig("usage").dig("total_tokens")}")

    build_response(extract_categorizations(response))
  end

  def instructions
    <<~INSTRUCTIONS
      You are an AI assistant that helps users identify merchants from personal finance transactions.

      Your goal is to analyze transaction descriptions and determine:
      1. The business/merchant name (cleaned up and standardized)
      2. The business website URL (if it's a well-known business)

      Rules:
      - Extract clean, standardized business names from transaction descriptions
      - Only include website URLs for well-known, established businesses
      - Prioritize user's existing merchants when there's a match
      - For unclear or generic descriptions, return null for both fields
      - Focus on identifying actual businesses rather than transaction types
    INSTRUCTIONS
  end

  private
    attr_reader :client, :model, :transactions, :user_merchants

    AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

    def build_response(categorizations)
      categorizations.map do |categorization|
        AutoDetectedMerchant.new(
          transaction_id: categorization["transaction_id"],
          business_name: normalize_ai_value(categorization["business_name"]),
          business_url: normalize_ai_value(categorization["business_url"])
        )
      end
    end

    def normalize_ai_value(ai_value)
      return nil if ai_value.blank? || ai_value.downcase == "null" || ai_value.downcase == "unknown"
      ai_value.strip
    end

    def extract_categorizations(response)
      JSON.parse(response.dig("output").first.dig("content").first.dig("text"))["merchants"]
    rescue JSON::ParserError, NoMethodError => e
      Rails.logger.error("Failed to parse OpenRouter auto-merchant-detection response: #{e.message}")
      []
    end

    def json_schema
      {
        type: "object",
        properties: {
          merchants: {
            type: "array",
            items: {
              type: "object",
              properties: {
                transaction_id: { type: "string" },
                business_name: { type: [ "string", "null" ] },
                business_url: { type: [ "string", "null" ] }
              },
              required: [ "transaction_id", "business_name", "business_url" ],
              additionalProperties: false
            }
          }
        },
        required: [ "merchants" ],
        additionalProperties: false
      }
    end

    def developer_message
      user_merchants_text = if user_merchants.any?
        "\n\nUser's existing merchants:\n" + user_merchants.map { |merchant| "- #{merchant[:name]}" }.join("\n")
      else
        ""
      end

      transactions_text = transactions.map do |txn|
        parts = []
        parts << "ID: #{txn[:id]}"
        parts << "Description: #{txn[:description]}"
        parts << "Amount: #{txn[:amount]}"
        parts << "Classification: #{txn[:classification]}"
        parts << "Current Merchant: #{txn[:merchant]}" if txn[:merchant].present?
        parts.join(", ")
      end.join("\n")

      <<~MESSAGE
        Please identify merchants from these personal finance transactions:

        #{transactions_text}#{user_merchants_text}

        Return a JSON response with merchant information for each transaction.
      MESSAGE
    end
end
