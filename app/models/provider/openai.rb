class Provider::Openai < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Openai::Error
  Error = Class.new(Provider::Error)

  MODELS = %w[gpt-4.1]

  def initialize(access_token)
    @client = ::OpenAI::Client.new(access_token: access_token)
  end

  def supports_model?(model)
    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [], model: "gpt-4.1-mini")
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      result = AutoCategorizer.new(
        client,
        model: model,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize

      log_langfuse_generation(
        name: "auto_categorize",
        model: model,
        input: { transactions: transactions, user_categories: user_categories },
        output: result.map(&:to_h)
      )

      result
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [], model: "gpt-4.1-mini")
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      result = AutoMerchantDetector.new(
        client,
        model: model,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants

      log_langfuse_generation(
        name: "auto_detect_merchants",
        model: model,
        input: { transactions: transactions, user_merchants: user_merchants },
        output: result.map(&:to_h)
      )

      result
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      collected_chunks = []

      # Proxy that converts raw stream to "LLM Provider concept" stream
      stream_proxy = if streamer.present?
        proc do |chunk|
          parsed_chunk = ChatStreamParser.new(chunk).parsed

          unless parsed_chunk.nil?
            streamer.call(parsed_chunk)
            collected_chunks << parsed_chunk
          end
        end
      else
        nil
      end

      input_payload = chat_config.build_input(prompt)

      raw_response = client.responses.create(parameters: {
        model: model,
        input: input_payload,
        instructions: instructions,
        tools: chat_config.tools,
        previous_response_id: previous_response_id,
        stream: stream_proxy
      })

      # If streaming, Ruby OpenAI does not return anything, so to normalize this method's API, we search
      # for the "response chunk" in the stream and return it (it is already parsed)
      if stream_proxy.present?
        response_chunk = collected_chunks.find { |chunk| chunk.type == "response" }
        response = response_chunk.data
        log_langfuse_generation(
          name: "chat_response",
          model: model,
          input: input_payload,
          output: response.messages.map(&:output_text).join("\n")
        )
        response
      else
        parsed = ChatParser.new(raw_response).parsed
        log_langfuse_generation(
          name: "chat_response",
          model: model,
          input: input_payload,
          output: parsed.messages.map(&:output_text).join("\n"),
          usage: raw_response["usage"]
        )
        parsed
      end
    end
  end

  private
    attr_reader :client

    def langfuse_client
      return unless ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?

      @langfuse_client = Langfuse.new
    end

    def log_langfuse_generation(name:, model:, input:, output:, usage: nil)
      return unless langfuse_client

      trace = langfuse_client.trace(name: "openai.#{name}", input: input)
      trace.generation(
        name: name,
        model: model,
        input: input,
        output: output,
        usage: usage
      )
      trace.update(output: output)
    rescue => e
      Rails.logger.warn("Langfuse logging failed: #{e.message}")
    end
end
