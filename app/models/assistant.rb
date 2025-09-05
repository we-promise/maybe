class Assistant
  include Provided, Configurable, Broadcastable, Assistant::Provided

  attr_reader :chat, :instructions

  class << self
    def for_chat(chat)
      config = config_for(chat)
      new(chat, instructions: config[:instructions], functions: config[:functions])
    end
  end

  def initialize(chat, instructions: nil, functions: [])
    @chat = chat
    @instructions = instructions
    @functions = functions
  end

  def respond_to(message)
    Rails.logger.info(">>> Assistant respond_to START - message: #{message.content}")
    Rails.logger.info(">>> Assistant respond_to - ai_model: #{message.ai_model}")

    # AI model verification
    if message.ai_model.blank?
      error_msg = "AI model not specified"
      Rails.logger.error(">>> Assistant respond_to - #{error_msg}")
      chat.add_error(StandardError.new(error_msg))
      return
    end

    # Creating the assistant message
    assistant_message = AssistantMessage.new(
      chat: chat,
      content: "",
      ai_model: message.ai_model
    )
    Rails.logger.info(">>> Assistant respond_to - assistant_message created")

    # Retrieve the model provider
    provider = get_model_provider(message.ai_model)
    Rails.logger.info(">>> Assistant respond_to - provider: #{provider.class.name if provider}")
    if provider.nil?
      error_msg = "Failed to get provider for model: #{message.ai_model}"
      Rails.logger.error(">>> Assistant respond_to - #{error_msg}")
      chat.add_error(StandardError.new(error_msg))
      return
    end

    responder = Assistant::Responder.new(
      message: message,
      instructions: instructions,
      function_tool_caller: function_tool_caller,
      llm: provider
    )
    Rails.logger.info(">>> Assistant respond_to - responder created")

    latest_response_id = chat.latest_assistant_response_id
    Rails.logger.info(">>> Assistant respond_to - latest_response_id: #{latest_response_id}")

    # Track if we've stopped thinking to avoid calling it multiple times
    thinking_stopped = false

    responder.on(:output_text) do |text|
      Rails.logger.info(">>> Assistant respond_to - output_text callback: #{text.inspect}")
      unless thinking_stopped
        stop_thinking
        thinking_stopped = true
      end

      if assistant_message.content.blank?
        Chat.transaction do
          assistant_message.append_text!(text)
          chat.update_latest_response!(latest_response_id)
        end
      else
        assistant_message.append_text!(text)
      end
    end

    responder.on(:response) do |data|
      Rails.logger.info(">>> Assistant respond_to - response callback: #{data.inspect}")
      update_thinking("Analyzing your data...")

      if data[:function_tool_calls].present?
        Rails.logger.info(">>> Assistant respond_to - function_tool_calls present: #{data[:function_tool_calls].inspect}")
        assistant_message.tool_calls = data[:function_tool_calls]
        latest_response_id = data[:id]
      else
        Rails.logger.info(">>> Assistant respond_to - updating latest_response_id: #{data[:id]}")
        chat.update_latest_response!(data[:id])
      end
    end

    Rails.logger.info(">>> Assistant respond_to - calling responder.respond")
    result = responder.respond(previous_response_id: latest_response_id)
    Rails.logger.info(">>> Assistant respond_to - result: #{result.inspect}")
    result
  rescue => e
    Rails.logger.error(">>> Assistant respond_to - error: #{e.message}")
    Rails.logger.error(">>> Assistant respond_to - backtrace: #{e.backtrace.first(5).join('\n')}")
    stop_thinking
    chat.add_error(e)
  end

  private
    attr_reader :functions

    def function_tool_caller
      function_instances = functions.map do |fn|
        fn.new(chat.user)
      end

      @function_tool_caller ||= FunctionToolCaller.new(function_instances)
    end
end
