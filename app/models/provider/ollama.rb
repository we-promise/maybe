require "net/http"
require "uri"
require "json"

class Provider::Ollama < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Ollama::Error
  Error = Class.new(Provider::Error)

  # Common Ollama models
  MODELS = %w[
    qwen3:4b
  ]

  def initialize(base_url)
    @base_url = base_url.chomp("/")
    Rails.logger.info(">>> Ollama initialized with base_url: #{@base_url}")
  end

  def supports_model?(model)
    MODELS.include?(model) || available_models.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [], model: "")
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      result = Provider::Ollama::AutoCategorizer.new(
        self,
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

      result = Provider::Ollama::AutoMerchantDetector.new(
        self,
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
      Rails.logger.info(">>> Ollama chat_response START - prompt: #{prompt.inspect}")
      Rails.logger.info(">>> Ollama chat_response - model: #{model}")
      Rails.logger.info(">>> Ollama chat_response - streamer present: #{streamer.present?}")
      Rails.logger.info(">>> Ollama chat_response - context: #{context.inspect}")

      # Vérification du contexte
      if !context.is_a?(Hash)
        context = {}
      end

      messages = build_messages(prompt, instructions, function_results)
      Rails.logger.info(">>> Ollama chat_response - built messages: #{messages.inspect}")

      payload = {
        model: model,
        messages: messages,
        stream: streamer.present?
      }

      # Add function tools if provided
      if functions.any?
        payload[:tools] = functions.map { |fn| format_tool(fn) }
      end

      Rails.logger.info(">>> Ollama chat_response - payload: #{payload.inspect}")

      result = if streamer.present?
        Rails.logger.info(">>> Ollama chat_response - using streaming response")
        handle_streaming_response(payload, streamer)
      else
        Rails.logger.info(">>> Ollama chat_response - using non-streaming response")
        handle_non_streaming_response(payload)
      end

      Rails.logger.info(">>> Ollama chat_response - result: #{result.inspect}")

      Rails.logger.info(">>> Ollama chat_response - result: #{result.inspect}")

      # Log to Langfuse with proper sanitization
      clean_input = begin
                      Rails.logger.info(">>> Ollama chat_response - cleaning input for Langfuse")
                      messages.is_a?(Array) ? messages.map { |m| m.respond_to?(:to_h) ? m.to_h : m }.to_json : messages.to_json
                    rescue => e
                      Rails.logger.warn(">>> Ollama chat_response - failed to clean input: #{e.message}")
                      prompt.to_s
                    end

      clean_output = begin
                       Rails.logger.info(">>> Ollama chat_response - cleaning output for Langfuse")
                       if result.messages.present?
                         output = result.messages.map { |msg| msg.output_text.to_s }.join("\n").presence || ""
                         Rails.logger.info(">>> Ollama chat_response - clean_output: #{output.inspect}")
                         output
                       else
                         Rails.logger.info(">>> Ollama chat_response - no messages in result")
                         ""
                       end
                     rescue => e
                       Rails.logger.warn(">>> Ollama chat_response - failed to clean output: #{e.message}")
                       result.inspect
                     end

      Rails.logger.info(">>> Ollama chat_response - calling log_langfuse_generation")
      log_langfuse_generation(
        name: "chat_response",
        model: model,
        input: clean_input,
        output: clean_output,
        context: context
      )

      Rails.logger.info(">>> Ollama chat_response - returning result")
      result
    end
  rescue => error
    raise Error, "Ollama chat error: #{error.message}"
  end

  # Ollama-specific method to get available models
  def available_models
    uri = URI("#{base_url}/api/tags")
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data["models"]&.map { |model| model["name"] } || []
    else
      raise Error, "Ollama API returned status #{response.code}: #{response.message}"
    end
  rescue Net::ConnectTimeoutError, Net::TimeoutError => e
    raise Error, "Connection timeout to Ollama at #{base_url}"
  rescue Errno::ECONNREFUSED => e
    raise Error, "Cannot connect to Ollama at #{base_url}. Make sure Ollama is running."
  rescue => e
    Rails.logger.warn("Failed to fetch Ollama models: #{e.message}")
    raise Error, "Failed to connect to Ollama: #{e.message}"
  end

  # Simple chat method for categorization/merchant detection
  def simple_chat(messages, model:)
    uri = URI("#{base_url}/api/chat")
    payload = {
      model: model,
      messages: messages,
      stream: false
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 60
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      raise Error, "Ollama API error: #{response.code} - #{response.body}"
    end
  end

  private
    attr_reader :base_url

    def build_messages(prompt, instructions, function_results)
      messages = []

      if instructions.present?
        messages << { role: "system", content: instructions }
      end

      messages << { role: "user", content: prompt }

      # Add function results as assistant messages
      function_results.each do |result|
        messages << {
          role: "assistant",
          content: "Function call result: #{result[:output]}"
        }
      end

      messages
    end

    def format_tool(function)
      {
        type: "function",
        function: {
          name: function[:name],
          description: function[:description],
          parameters: function[:params_schema]
        }
      }
    end

    def handle_streaming_response(payload, streamer)
      collected_content = ""
      tool_calls = []

      uri = URI("#{base_url}/api/chat")

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 60
      http.read_timeout = 180  # Increasing the timeout for slower models= 180  # Augmentation du délai pour les modèles plus lents

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = payload.to_json

      http.request(request) do |response|
        if response.is_a?(Net::HTTPSuccess)
          response.read_body do |chunk|
            chunk.each_line do |line|
              next if line.strip.empty?

              begin
                data = JSON.parse(line)

                # Extract tool calls from first chunk
                if data["message"] && data["message"]["tool_calls"] && tool_calls.empty?
                  tool_calls = data["message"]["tool_calls"]
                  Rails.logger.info(">>> Ollama handle_streaming_response - extracted tool_calls: #{tool_calls.inspect}")
                end

                # Extract content from chunks
                if data["message"] && data["message"]["content"]
                  content_value = data["message"]["content"]
                  # Handle different content types
                  chunk_content = case content_value
                  when String
                    content_value
                  when Hash
                    # Sometimes Ollama returns structured content
                    content_value["text"] || content_value.to_json
                  else
                    content_value.to_s
                  end

                  # Process thinking content to remove tags
                  processed_content = process_thinking_content(chunk_content)

                  # Add all content to collected content
                  collected_content += processed_content.to_s

                  # Send all chunks to streamer
                  if processed_content.present?
                    chunk = Provider::LlmConcept::ChatStreamChunk.new(
                      type: "output_text",
                      data: processed_content
                    )
                    streamer.call(chunk)
                  end
                end

                if data["done"]
                  if collected_content.blank?
                    collected_content = "Sorry, I couldn't generate a response. Please try again."
                  end

                  # Clean up any remaining thinking content from final response
                  final_content = collected_content

                  # Build function requests from tool calls
                  function_requests = tool_calls.map do |tool_call|
                    Provider::LlmConcept::ChatFunctionRequest.new(
                      id: SecureRandom.uuid,
                      call_id: SecureRandom.uuid,
                      function_name: tool_call.dig("function", "name"),
                      function_args: JSON.parse(tool_call.dig("function", "arguments") || "{}")
                    )
                  end

                  # Send final response
                  response_data = Provider::LlmConcept::ChatResponse.new(
                    id: SecureRandom.uuid,
                    model: payload[:model],
                    messages: [
                      Provider::LlmConcept::ChatMessage.new(
                        id: SecureRandom.uuid,
                        output_text: final_content
                      )
                    ],
                    function_requests: function_requests
                  )

                  final_chunk = Provider::LlmConcept::ChatStreamChunk.new(
                    type: "response",
                    data: response_data
                  )
                  streamer.call(final_chunk)

                  return response_data
                end
              rescue JSON::ParserError
                Rails.logger.warn(">>> Ollama handle_streaming_response - JSON parse error for line: #{line.inspect}")
                # Skip invalid JSON lines
                next
              end
            end
          end
        else
          error_msg = "Ollama streaming error: #{response.code} - #{response.body}"
          Rails.logger.error(">>> Ollama handle_streaming_response - HTTP error: #{error_msg}")
          raise Error, error_msg
        end
      end

      Rails.logger.info(">>> Ollama handle_streaming_response - reached end without done=true")

      # Si on arrive ici, c'est qu'aucune réponse n'a été générée
      if collected_content.blank?
        response_data = Provider::LlmConcept::ChatResponse.new(
          id: SecureRandom.uuid,
          model: payload[:model],
          messages: [
            Provider::LlmConcept::ChatMessage.new(
              id: SecureRandom.uuid,
              output_text: "Sorry, I couldn't generate a response. Please try again."
            )
          ],
          function_requests: []
        )

        final_chunk = Provider::LlmConcept::ChatStreamChunk.new(
          type: "response",
          data: response_data
        )
        streamer.call(final_chunk)

        response_data
      end
    rescue => e
      raise Error, "Ollama streaming error: #{e.message}"
    end

    def handle_non_streaming_response(payload)
      uri = URI("#{base_url}/api/chat")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 60
      http.read_timeout = 120  # Augmentation du délai pour les modèles plus lents

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = payload.to_json

      begin
        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          content_value = data.dig("message", "content")

          # Handle different content types
          content = case content_value
          when String
            content_value
          when Hash
            # Sometimes Ollama returns structured content
            content_value["text"] || content_value.to_json
          when nil
            ""
          else
            content_value.to_s
          end

          # Traiter le cas où le contenu est vide
          if content.blank?
            content = "Sorry, I couldn't generate a response. Please try again."
          end

          # Vérifier si on a des tool calls
          tool_calls = data.dig("message", "tool_calls") || []
          function_requests = []

          if tool_calls.any?
            function_requests = tool_calls.map do |tool_call|
              Provider::LlmConcept::ChatFunctionRequest.new(
                id: SecureRandom.uuid,
                call_id: SecureRandom.uuid,
                function_name: tool_call.dig("function", "name"),
                function_args: JSON.parse(tool_call.dig("function", "arguments") || "{}")
              )
            end
          end

          chat_response = Provider::LlmConcept::ChatResponse.new(
            id: SecureRandom.uuid,
            model: payload[:model],
            messages: [
              Provider::LlmConcept::ChatMessage.new(
                id: SecureRandom.uuid,
                output_text: content
              )
            ],
            function_requests: function_requests
          )

          chat_response
        else
          error_msg = "Ollama API error: #{response.code} - #{response.body}"
          raise Error, error_msg
        end
      rescue JSON::ParserError => e
        raise Error, "Failed to parse Ollama response: #{e.message}"
      rescue Net::ReadTimeout => e
        raise Error, "Ollama request timed out. The model might be too slow or unavailable."
      rescue => e
        raise Error, "Ollama error: #{e.message}"
      end
    end

    def process_thinking_content(content)
      # Simply remove thinking tags and display content normally
      return content unless content.include?("<think>") || content.include?("</think>")

      # Remove thinking tags completely
      processed = content.dup
      processed = processed.gsub(/<think>/, "")
      processed = processed.gsub(/<\/think>/, "")

      processed
    end

    def langfuse_client
      return unless ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?

      @langfuse_client = Langfuse.new
    end

    def log_langfuse_generation(name:, model:, input:, output:, usage: nil, context: {})
      Rails.logger.info(">>> Ollama log_langfuse_generation START")
      Rails.logger.info(">>> Ollama log_langfuse_generation - name: #{name}")
      Rails.logger.info(">>> Ollama log_langfuse_generation - model: #{model}")
      Rails.logger.info(">>> Ollama log_langfuse_generation - input: #{input.inspect}")
      Rails.logger.info(">>> Ollama log_langfuse_generation - output: #{output.inspect}")
      Rails.logger.info(">>> Ollama log_langfuse_generation - context: #{context.inspect}")

      return unless langfuse_client
      Rails.logger.info(">>> Ollama log_langfuse_generation - langfuse_client available")

      # Validation of inputs for Langfuse
      begin
        trace_id = context[:chat_id] ? "chat_#{context[:chat_id]}" : nil
        user_id = context[:user_id]
        Rails.logger.info(">>> Ollama log_langfuse_generation - trace_id: #{trace_id}, user_id: #{user_id}")

        safe_input = input.presence || ""
        safe_output = output.presence || ""

        safe_input = safe_input.to_s[0...10000] if safe_input.to_s.length > 10000
        safe_output = safe_output.to_s[0...10000] if safe_output.to_s.length > 10000

        Rails.logger.info(">>> Ollama log_langfuse_generation - safe_input: #{safe_input.inspect}")
        Rails.logger.info(">>> Ollama log_langfuse_generation - safe_output: #{safe_output.inspect}")

        trace = langfuse_client.trace(
          name: "ollama.#{name}",
          input: safe_input,
          trace_id: trace_id,
          user_id: user_id
        )
        Rails.logger.info(">>> Ollama log_langfuse_generation - trace created: #{trace.inspect}")

        generation = trace.generation(
          name: name,
          model: model,
          input: safe_input,
          output: safe_output,
          usage: usage
        )
        Rails.logger.info(">>> Ollama log_langfuse_generation - generation created: #{generation.inspect}")

        # Add additional metadata from context
        if context.present?
          generation.update(metadata: context.transform_values(&:to_s))
          Rails.logger.info(">>> Ollama log_langfuse_generation - metadata updated")
        end

        trace.update(output: safe_output)
        Rails.logger.info(">>> Ollama log_langfuse_generation - trace updated")

      rescue => e
        Rails.logger.warn(">>> Ollama log_langfuse_generation - error: #{e.message}")
        Rails.logger.warn(">>> Ollama log_langfuse_generation - backtrace: #{e.backtrace.first(3).join('\n')}")
      end
      Rails.logger.info(">>> Ollama log_langfuse_generation END")
    end
end
