module Assistant::Provided
  extend ActiveSupport::Concern

  def get_model_provider(ai_model)
    # First, try to find a provider that explicitly supports the model
    provider = registry.providers.find { |provider| provider&.supports_model?(ai_model) }

    # If no provider explicitly supports the model, fall back to the preferred provider
    provider || registry.preferred_ai_provider
  end

  private
    def registry
      @registry ||= Provider::Registry.for_concept(:llm)
    end
end
