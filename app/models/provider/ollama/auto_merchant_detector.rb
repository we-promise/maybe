class Provider::Ollama::AutoMerchantDetector
  DEFAULT_MODEL = "llama3.2"

  def initialize(provider, model: "", transactions:, user_merchants:)
    @provider = provider
    @model = model
    @transactions = transactions
    @user_merchants = user_merchants
  end

  def auto_detect_merchants
    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: user_message }
    ]

    response = provider.simple_chat(messages, model: model.presence || DEFAULT_MODEL)
    content = response.dig("message", "content")

    Rails.logger.info("Ollama merchant detection response: #{content}")

    build_response(parse_response(content))
  end

  private
    attr_reader :provider, :model, :transactions, :user_merchants

    AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

    def system_prompt
      <<~PROMPT
        You are an AI assistant that helps identify merchants from personal finance transactions.

        Rules:
        - Extract clean, standardized business names from transaction descriptions
        - Only include website URLs for well-known, established businesses
        - Prioritize user's existing merchants when there's a match
        - For unclear or generic descriptions, use null for both fields
        - Focus on identifying actual businesses rather than transaction types

        You must respond with valid JSON in this exact format:
        {
          "merchants": [
            {"transaction_id": "1", "business_name": "McDonald's", "business_url": "mcdonalds.com"},
            {"transaction_id": "2", "business_name": null, "business_url": null}
          ]
        }
      PROMPT
    end

    def user_message
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

        Return only valid JSON with merchant information for each transaction.
      MESSAGE
    end

    def parse_response(content)
      # Try to extract JSON from the response
      json_match = content.match(/\{.*\}/m)

      if json_match
        JSON.parse(json_match[0])["merchants"]
      else
        Rails.logger.error("No valid JSON found in Ollama merchant detection response: #{content}")
        []
      end
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse Ollama merchant detection response: #{e.message}")
      []
    end

    def build_response(merchants)
      merchants.map do |merchant|
        AutoDetectedMerchant.new(
          transaction_id: merchant["transaction_id"],
          business_name: normalize_ai_value(merchant["business_name"]),
          business_url: normalize_ai_value(merchant["business_url"])
        )
      end
    end

    def normalize_ai_value(ai_value)
      return nil if ai_value.blank? || ai_value.to_s.downcase == "null" || ai_value.to_s.downcase == "unknown"
      ai_value.strip
    end
end
