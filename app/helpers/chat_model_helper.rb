module ChatModelHelper
  def self.available_models
    openrouter_models = Provider::Openrouter::MODELS
    ollama_models = Provider::Ollama::MODELS

    # Return combined unique models, sorted alphabetically
    (openrouter_models + ollama_models).uniq.sort
  end

  def self.model_provider(model)
    if Provider::Openrouter::MODELS.include?(model)
      "openrouter"
    elsif Provider::Ollama::MODELS.include?(model)
      "ollama"
    else
      # Default to the preferred AI provider
      Setting.ai_provider || "openrouter"
    end
  end

  def self.langfuse_trace_url(trace_id)
    host = ENV["LANGFUSE_HOST"] || "https://cloud.langfuse.com"
    "#{host}/project/traces/#{trace_id}"
  end
end
