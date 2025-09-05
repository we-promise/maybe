class UserMessage < Message
  validates :ai_model, presence: true

  after_create_commit :request_response_later
  after_create_commit :log_to_langfuse

  def role
    "user"
  end

  def request_response_later
    chat.ask_assistant_later(self)
  end

  def request_response
    chat.ask_assistant(self)
  end

  private
    def log_to_langfuse
      LangfuseLogger.log_chat_interaction(self)
    end
end
