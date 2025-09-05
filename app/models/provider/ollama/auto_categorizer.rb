class Provider::Ollama::AutoCategorizer
  DEFAULT_MODEL = "llama3.2"

  def initialize(provider, model: "", transactions: [], user_categories: [])
    @provider = provider
    @model = model
    @transactions = transactions
    @user_categories = user_categories
  end

  def auto_categorize
    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: user_message }
    ]

    response = provider.simple_chat(messages, model: model.presence || DEFAULT_MODEL)
    content = response.dig("message", "content")

    Rails.logger.info("Ollama categorization response: #{content}")

    build_response(parse_response(content))
  end

  private
    attr_reader :provider, :model, :transactions, :user_categories

    AutoCategorization = Provider::LlmConcept::AutoCategorization

    def system_prompt
      <<~PROMPT
        You are an AI assistant that helps categorize personal finance transactions.

        Rules:
        - Always prioritize user's existing categories over creating new ones
        - Be consistent with category naming (use title case)
        - Consider the transaction amount and description to determine the most appropriate category
        - For unclear transactions, make your best educated guess
        - Focus on broad, useful categories rather than overly specific ones

        You must respond with valid JSON in this exact format:
        {
          "categorizations": [
            {"transaction_id": "1", "category_name": "Groceries"},
            {"transaction_id": "2", "category_name": "Transportation"}
          ]
        }
      PROMPT
    end

    def user_message
      user_categories_text = if user_categories.any?
        "\n\nUser's existing categories:\n" + user_categories.map { |cat| "- #{cat[:name]}" }.join("\n")
      else
        ""
      end

      transactions_text = transactions.map do |txn|
        parts = []
        parts << "ID: #{txn[:id]}"
        parts << "Name: #{txn[:name]}"
        parts << "Amount: #{txn[:amount]}"
        parts << "Classification: #{txn[:classification]}"
        parts << "Merchant: #{txn[:merchant]}" if txn[:merchant].present?
        parts << "Hint: #{txn[:hint]}" if txn[:hint].present?
        parts.join(", ")
      end.join("\n")

      <<~MESSAGE
        Please categorize these personal finance transactions:

        #{transactions_text}#{user_categories_text}

        Return only valid JSON with categorizations for each transaction.
      MESSAGE
    end

    def parse_response(content)
      # Try to extract JSON from the response
      json_match = content.match(/\{.*\}/m)

      if json_match
        JSON.parse(json_match[0])["categorizations"]
      else
        Rails.logger.error("No valid JSON found in Ollama categorization response: #{content}")
        []
      end
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse Ollama categorization response: #{e.message}")
      []
    end

    def build_response(categorizations)
      categorizations.map do |categorization|
        AutoCategorization.new(
          transaction_id: categorization["transaction_id"],
          category_name: normalize_category_name(categorization["category_name"])
        )
      end
    end

    def normalize_category_name(category_name)
      category_name.strip.titleize
    end
end
