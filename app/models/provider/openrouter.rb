class Provider::Openrouter < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Openrouter::Error
  Error = Class.new(Provider::Error)

  # Popular models available on OpenRouter
  MODELS = %w[
    openai/gpt-4o
    openai/gpt-4o-mini
    openai/gpt-4-turbo
    openai/gpt-3.5-turbo
    anthropic/claude-3.5-sonnet
    anthropic/claude-3-haiku
    meta-llama/llama-3.2-3b-instruct
    meta-llama/llama-3.2-11b-instruct
    qwen/qwen-2.5-72b-instruct
    google/gemini-pro-1.5
  ]

  def initialize(api_key)
    @client = ::OpenAI::Client.new(
      access_token: api_key,
      uri_base: "https://openrouter.ai/api/v1",
      extra_headers: {
        "HTTP-Referer" => "https://maybe.co",
        "X-Title" => "Maybe Finance"
      }
    )
  end

  def supports_model?(model)
    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [], model: "")
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      result = Provider::Openrouter::AutoCategorizer.new(
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

  def auto_detect_merchants(transactions: [], user_merchants: [], model: "")
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      result = Provider::Openrouter::AutoMerchantDetector.new(
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

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil, context: {})
    with_provider_response do
      chat_config = Provider::Openrouter::ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      collected_chunks = []

      # Proxy that converts raw stream to "LLM Provider concept" stream
      stream_proxy = if streamer.present?
        proc do |chunk|
          parsed_chunk = Provider::Openrouter::ChatStreamParser.new(chunk).parsed

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
        # Verification that response_chunk exists
        if !response_chunk
          raise Error, "No response chunk found in collected chunks"
        end

        response = response_chunk.data

        # Assurons-nous que input_payload et output sont des chaînes pour Langfuse
        clean_input = input_payload.is_a?(Array) ? input_payload.map(&:to_h).to_json : input_payload.to_json
        clean_output = response.messages.map(&:output_text).join("\n").presence || ""

        log_langfuse_generation(
          name: "chat_response",
          model: model,
          input: clean_input,
          output: clean_output,
          context: context
        )
        response
      else
        parsed = Provider::Openrouter::ChatParser.new(raw_response).parsed

        # Assurons-nous que input_payload et output sont des chaînes pour Langfuse
        clean_input = input_payload.is_a?(Array) ? input_payload.map(&:to_h).to_json : input_payload.to_json
        clean_output = parsed.messages.map(&:output_text).join("\n").presence || ""

        log_langfuse_generation(
          name: "chat_response",
          model: model,
          input: clean_input,
          output: clean_output,
          usage: raw_response["usage"],
          context: context
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

    def log_langfuse_generation(name:, model:, input:, output:, usage: nil, context: {})
      return unless langfuse_client

      begin
        trace_id = context[:chat_id] ? "chat_#{context[:chat_id]}" : nil
        user_id = context[:user_id]

        safe_input = input.presence || ""
        safe_output = output.presence || ""

        safe_input = safe_input.to_s[0...10000] if safe_input.to_s.length > 10000
        safe_output = safe_output.to_s[0...10000] if safe_output.to_s.length > 10000

        trace = langfuse_client.trace(
          name: "openrouter.#{name}",
          input: safe_input,
          trace_id: trace_id,
          user_id: user_id
        )

        generation = trace.generation(
          name: name,
          model: model,
          input: safe_input,
          output: safe_output,
          usage: usage
        )

        # Add additional metadata from context
        if context.present?
          generation.update(metadata: context.transform_values(&:to_s))
        end

        trace.update(output: safe_output)

      rescue => e
        Rails.logger.warn("Langfuse logging failed: #{e.message}")
        Rails.logger.warn("Langfuse logging backtrace: #{e.backtrace.first(3).join('\n')}")
      end
    end
end
