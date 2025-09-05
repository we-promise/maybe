class LangfuseLogger
  class << self
    def log_chat_interaction(message)
      return unless langfuse_enabled?

      chat = message.chat
      user = chat.user

      # Create or continue a trace for this chat
      trace_id = "chat_#{chat.id}"
      user_id = user.id.to_s

      trace = Langfuse.new.trace(
        name: "Chat Session",
        trace_id: trace_id,
        user_id: user_id,
        metadata: {
          chat_id: chat.id,
          chat_title: chat.title
        }
      )

      # Log the interaction based on message type
      case message
      when UserMessage
        trace.span(
          name: "User Message",
          input: message.content,
          metadata: {
            message_id: message.id,
            timestamp: message.created_at,
            message_type: "user",
            ai_model: message.ai_model
          }
        )
      when AssistantMessage
        # Pour les messages de l'assistant, content est toujours l'output
        # Si tool_calls est présent, l'inclure dans metadata pour le traçage
        input = chat.messages.where(type: "UserMessage").last&.content || ""
        trace.span(
          name: "Assistant Response",
          input: input,
          output: message.content,
          metadata: {
            message_id: message.id,
            timestamp: message.created_at,
            message_type: "assistant",
            ai_model: message.ai_model,
            tool_calls: message.tool_calls
          }
        )
      end

      trace
    rescue => e
      Rails.logger.warn("Langfuse chat logging failed: #{e.message}")
      nil
    end

    private

      def langfuse_enabled?
        ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
      end
  end
end
