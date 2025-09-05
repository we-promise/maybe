require "test_helper"

class Settings::AiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    sign_in @user
  end

  test "should get show" do
    get settings_ai_path
    assert_response :success
    assert_select "h2", "AI Provider Settings"
  end

  test "should update ai provider settings" do
    assert_changes -> { Setting.ai_provider }, to: "openrouter" do
      patch settings_ai_path, params: {
        setting: {
          ai_provider: "openrouter",
          openrouter_api_key: "test-key"
        }
      }
    end

    assert_redirected_to settings_ai_path
    assert_equal "test-key", Setting.openrouter_api_key
  end

  test "should clear other provider settings when switching providers" do
    # Set initial OpenAI settings
    Setting.openai_access_token = "test-openai-key"
    Setting.ai_provider = "openai"

    # Switch to OpenRouter
    patch settings_ai_path, params: {
      setting: {
        ai_provider: "openrouter",
        openrouter_api_key: "test-openrouter-key"
      }
    }

    assert_equal "openrouter", Setting.ai_provider
    assert_equal "test-openrouter-key", Setting.openrouter_api_key
    assert_nil Setting.openai_access_token
  end

  test "should not update masked password fields" do
    Setting.openai_access_token = "original-key"

    patch settings_ai_path, params: {
      setting: {
        ai_provider: "openai",
        openai_access_token: "********"
      }
    }

    # Should keep original key when masked value is submitted
    assert_equal "original-key", Setting.openai_access_token
  end

  test "should handle update errors gracefully" do
    # Simulate an error by stubbing Setting to raise an exception
    Setting.stubs(:ai_provider=).raises(StandardError.new("Test error"))

    patch settings_ai_path, params: {
      setting: {
        ai_provider: "openrouter"
      }
    }

    assert_redirected_to settings_ai_path
    follow_redirect!
    assert_select ".alert", /Failed to update AI settings/
  end
end
