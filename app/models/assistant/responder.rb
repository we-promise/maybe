class Assistant::Responder
  def initialize(message:, instructions:, function_tool_caller:, llm:)
    @message = message
    @instructions = instructions
    @function_tool_caller = function_tool_caller
    @llm = llm
  end

  def on(event_name, &block)
    listeners[event_name.to_sym] << block
  end

  def respond(previous_response_id: nil)
    Rails.logger.info(">>> Responder respond START")
    # Store context for Langfuse
    @context = {
      chat_id: message.chat.id,
      user_id: message.chat.user.id,
      message_id: message.id
    }
    Rails.logger.info(">>> Responder respond - context: #{@context.inspect}")

    # For the first response
    streamer = proc do |chunk|
      Rails.logger.info(">>> Responder respond - streamer callback: #{chunk.inspect}")
      case chunk.type
      when "output_text"
        Rails.logger.info(">>> Responder respond - emitting output_text: #{chunk.data.inspect}")
        emit(:output_text, chunk.data)
      when "response"
        response = chunk.data
        Rails.logger.info(">>> Responder respond - response chunk: #{response.inspect}")

        if response.function_requests.any?
          Rails.logger.info(">>> Responder respond - handling follow-up response")
          handle_follow_up_response(response)
        else
          Rails.logger.info(">>> Responder respond - emitting response: #{response.id}")
          emit(:response, { id: response.id })
        end
      end
    end

    Rails.logger.info(">>> Responder respond - calling get_llm_response")
    get_llm_response(streamer: streamer, previous_response_id: previous_response_id)
  end

  private
    attr_reader :message, :instructions, :function_tool_caller, :llm

    def handle_follow_up_response(response)
      streamer = proc do |chunk|
        case chunk.type
        when "output_text"
          emit(:output_text, chunk.data)
        when "response"
          # We do not currently support function executions for a follow-up response (avoid recursive LLM calls that could lead to high spend)
          emit(:response, { id: chunk.data.id })
        end
      end

      function_tool_calls = function_tool_caller.fulfill_requests(response.function_requests)

      emit(:response, {
        id: response.id,
        function_tool_calls: function_tool_calls
      })

      # Get follow-up response with tool call results
      get_llm_response(
        streamer: streamer,
        function_results: function_tool_calls.map(&:to_result),
        previous_response_id: response.id
      )
    end

    def get_llm_response(streamer:, function_results: [], previous_response_id: nil)
      Rails.logger.info(">>> Responder get_llm_response START")
      Rails.logger.info(">>> Responder get_llm_response - message.content: #{message.content.inspect}")
      Rails.logger.info(">>> Responder get_llm_response - message.ai_model: #{message.ai_model}")
      Rails.logger.info(">>> Responder get_llm_response - instructions: #{instructions.inspect}")
      Rails.logger.info(">>> Responder get_llm_response - function_results: #{function_results.inspect}")
      Rails.logger.info(">>> Responder get_llm_response - previous_response_id: #{previous_response_id}")
      Rails.logger.info(">>> Responder get_llm_response - context: #{@context.inspect}")

      response = llm.chat_response(
        message.content,
        model: message.ai_model,
        instructions: instructions,
        functions: function_tool_caller.function_definitions,
        function_results: function_results,
        streamer: streamer,
        previous_response_id: previous_response_id,
        context: @context # Pass context for Langfuse
      )

      Rails.logger.info(">>> Responder get_llm_response - response: #{response.inspect}")

      unless response.success?
        Rails.logger.error(">>> Responder get_llm_response - response failed: #{response.error.inspect}")
        raise response.error
      end

      Rails.logger.info(">>> Responder get_llm_response - returning: #{response.data.inspect}")
      response.data
    end

    def emit(event_name, payload = nil)
      listeners[event_name.to_sym].each { |block| block.call(payload) }
    end

    def listeners
      @listeners ||= Hash.new { |h, k| h[k] = [] }
    end
end
