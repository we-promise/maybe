class Provider::Openrouter::AutoCategorizer
  DEFAULT_MODEL = "openai/gpt-4o-mini"

  def initialize(client, model: "", transactions: [], user_categories: [])
    @client = client
    @model = model
    @transactions = transactions
    @user_categories = user_categories
  end

  def auto_categorize
    response = client.responses.create(parameters: {
      model: model.presence || DEFAULT_MODEL,
      input: [ { role: "developer", content: developer_message } ],
      text: {
        format: {
          type: "json_schema",
          name: "auto_categorize_personal_finance_transactions",
          strict: true,
          schema: json_schema
        }
      },
      instructions: instructions
    })

    Rails.logger.info("Tokens used to auto-categorize transactions: #{response.dig("usage").dig("total_tokens")}")

    build_response(extract_categorizations(response))
  end

  def instructions
    <<~INSTRUCTIONS
      You are an AI assistant that helps users categorize their personal finance transactions.

      Your goal is to analyze the provided transactions and assign appropriate categories based on:
      1. Transaction name/description
      2. Amount (can help determine if it's a bill vs one-time purchase)
      3. Any existing merchant information
      4. Hints provided by the user
      5. User's existing categories (prioritize these when possible)

      Rules:
      - Always prioritize user's existing categories over creating new ones
      - Be consistent with category naming (use title case)
      - Consider the transaction amount and description to determine the most appropriate category
      - For unclear transactions, make your best educated guess
      - Focus on broad, useful categories rather than overly specific ones
    INSTRUCTIONS
  end

  private
    attr_reader :client, :model, :transactions, :user_categories

    AutoCategorization = Provider::LlmConcept::AutoCategorization

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

    def extract_categorizations(response)
      JSON.parse(response.dig("output").first.dig("content").first.dig("text"))["categorizations"]
    rescue JSON::ParserError, NoMethodError => e
      Rails.logger.error("Failed to parse OpenRouter auto-categorization response: #{e.message}")
      []
    end

    def json_schema
      {
        type: "object",
        properties: {
          categorizations: {
            type: "array",
            items: {
              type: "object",
              properties: {
                transaction_id: { type: "string" },
                category_name: { type: "string" }
              },
              required: [ "transaction_id", "category_name" ],
              additionalProperties: false
            }
          }
        },
        required: [ "categorizations" ],
        additionalProperties: false
      }
    end

    def developer_message
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

        Return a JSON response with categorizations for each transaction.
      MESSAGE
    end
end
