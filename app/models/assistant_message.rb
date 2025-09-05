class AssistantMessage < Message
  validates :ai_model, presence: true

  after_update_commit :log_to_langfuse, if: :should_log_to_langfuse?

  def role
    "assistant"
  end

  def append_text!(text)
    self.content += text
    save!
  end

  private
    def log_to_langfuse
      LangfuseLogger.log_chat_interaction(self)
    end

    def should_log_to_langfuse?
      # Only log when content changes and it's not empty
      saved_change_to_content? && content.present?
    end
end
