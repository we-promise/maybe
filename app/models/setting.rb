# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  field :twelve_data_api_key, type: :string, default: ENV["TWELVE_DATA_API_KEY"]
  field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]
  field :brand_fetch_client_id, type: :string, default: ENV["BRAND_FETCH_CLIENT_ID"]

  # AI Provider Settings
  field :ai_provider, type: :string, default: "openrouter"
  field :ai_model, type: :string, default: "openai/gpt-4o-mini"
  field :openrouter_api_key, type: :string
  field :ollama_base_url, type: :string, default: "http://host.docker.internal:11434"

  field :require_invite_for_signup, type: :boolean, default: false
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"
end
