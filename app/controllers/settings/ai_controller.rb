class Settings::AiController < ApplicationController
  layout "settings"

  def show
    @breadcrumbs = [
      [ "Home", root_path ],
      [ "AI Settings", nil ]
    ]
    @family = Current.family
    @assistant_config = Assistant.config_for(OpenStruct.new(user: Current.user))
  end

  def test_connection
    provider = params[:provider]

    begin
      case provider
      when "openrouter"
        api_key = params[:api_key].presence || Setting.openrouter_api_key
        raise "API key required" if api_key.blank?

        provider_instance = Provider::Openrouter.new(api_key)
        # Test with a simple model check
        if provider_instance.supports_model?("openai/gpt-4o-mini")
          render json: { success: true, message: "OpenRouter connection successful!" }
        else
          render json: { success: false, message: "OpenRouter connection failed" }
        end

      when "ollama"
        base_url = params[:base_url].presence || Setting.ollama_base_url
        provider_instance = Provider::Ollama.new(base_url)

        # Test connection by trying to get models list
        models = provider_instance.send(:available_models)
        if models.any?
          render json: { success: true, message: "Ollama connection successful! Found #{models.size} models." }
        else
          render json: { success: false, message: "Ollama connection failed or no models found. Make sure Ollama is running and has models installed." }
        end

      else
        render json: { success: false, message: "Unknown provider" }
      end
    rescue => e
      render json: { success: false, message: "Connection failed: #{e.message}" }
    end
  end

  def models
    provider = params[:provider]

    begin
      case provider
      when "openrouter"
        models = Provider::Openrouter::MODELS
        render json: { success: true, models: models }

      when "ollama"
        base_url = params[:base_url].presence || Setting.ollama_base_url
        provider_instance = Provider::Ollama.new(base_url)
        models = provider_instance.send(:available_models)

        # Fallback to default models if none available
        models = Provider::Ollama::MODELS if models.empty?

        render json: { success: true, models: models }

      else
        render json: { success: false, message: "Unknown provider" }
      end
    rescue => e
      render json: { success: false, message: "Failed to get models: #{e.message}" }
    end
  end

  def update
    permitted_params = params.require(:setting).permit(
      :ai_provider,
      :ai_model,
      :openrouter_api_key,
      :ollama_base_url
    )

    # Clear provider-specific settings when switching providers
    if params[:setting][:ai_provider] != Setting.ai_provider
      case params[:setting][:ai_provider]
      when "openrouter"
        permitted_params[:ollama_base_url] = "http://host.docker.internal:11434"
        permitted_params[:ai_model] = "openai/gpt-4o-mini" if params[:setting][:ai_model].blank?
      when "ollama"
        permitted_params[:openrouter_api_key] = nil
        permitted_params[:ai_model] = "llama3.2:3b" if params[:setting][:ai_model].blank?
      end
    end

    # Update each setting individually
    permitted_params.each do |key, value|
      Setting.send("#{key}=", value) if value != "********"
    end

    redirect_to settings_ai_path, notice: "AI settings updated successfully."
  rescue => e
    Rails.logger.error("Failed to update AI settings: #{e.message}")
    redirect_to settings_ai_path, alert: "Failed to update AI settings."
  end

  private

    def require_self_hosted
      redirect_to root_path unless Rails.application.config.app_mode.self_hosted?
    end
end
