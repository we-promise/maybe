require "test_helper"

class Provider::RegistryTest < ActiveSupport::TestCase
  test "returns preferred ai provider based on settings" do
    # Test default (OpenAI)
    Setting.ai_provider = "openai"
    Setting.openai_access_token = "test-key"

    registry = Provider::Registry.for_concept(:llm)
    provider = registry.preferred_ai_provider

    assert_instance_of Provider::Openai, provider
  end

  test "returns openrouter when configured as preferred" do
    Setting.ai_provider = "openrouter"
    Setting.openrouter_api_key = "test-key"

    registry = Provider::Registry.for_concept(:llm)
    provider = registry.preferred_ai_provider

    assert_instance_of Provider::Openrouter, provider
  end

  test "returns ollama when configured as preferred" do
    Setting.ai_provider = "ollama"
    Setting.ollama_base_url = "http://host.docker.internal:11434"

    registry = Provider::Registry.for_concept(:llm)
    provider = registry.preferred_ai_provider

    assert_instance_of Provider::Ollama, provider
  end

  test "falls back to available provider when preferred is not configured" do
    Setting.ai_provider = "openrouter"
    Setting.openrouter_api_key = nil # Not configured
    Setting.openai_access_token = "test-key" # But OpenAI is

    registry = Provider::Registry.for_concept(:llm)
    provider = registry.preferred_ai_provider

    # Should fall back to OpenAI since OpenRouter isn't configured
    assert_instance_of Provider::Openai, provider
  end

  test "returns nil when no ai provider is configured" do
    Setting.ai_provider = "openai"
    Setting.openai_access_token = nil
    Setting.openrouter_api_key = nil
    Setting.ollama_base_url = nil

    registry = Provider::Registry.for_concept(:llm)
    provider = registry.preferred_ai_provider

    assert_nil provider
  end

  test "includes all ai providers in available providers for llm concept" do
    registry = Provider::Registry.for_concept(:llm)
    available = registry.send(:available_providers)

    assert_includes available, :openai
    assert_includes available, :openrouter
    assert_includes available, :ollama
  end
end
