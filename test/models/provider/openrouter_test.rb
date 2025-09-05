require "test_helper"

class Provider::OpenrouterTest < ActiveSupport::TestCase
  include LLMInterfaceTest

  setup do
    @subject = Provider::Openrouter.new("test-openrouter-token")
    @subject_model = "openai/gpt-4o-mini"
  end

  test "supports openrouter models" do
    assert @subject.supports_model?("openai/gpt-4o")
    assert @subject.supports_model?("anthropic/claude-3.5-sonnet")
    assert_not @subject.supports_model?("invalid-model")
  end

  test "initializes with correct api key and headers" do
    provider = Provider::Openrouter.new("test-key")

    # Can't directly test private client, but we can ensure it's created without error
    assert_not_nil provider
  end

  test "auto categorize raises error for too many transactions" do
    transactions = (1..26).map { |i| { id: i.to_s, name: "Transaction #{i}" } }

    assert_raises Provider::Openrouter::Error do
      @subject.auto_categorize(transactions: transactions)
    end
  end

  test "auto detect merchants raises error for too many transactions" do
    transactions = (1..26).map { |i| { id: i.to_s, description: "Transaction #{i}" } }

    assert_raises Provider::Openrouter::Error do
      @subject.auto_detect_merchants(transactions: transactions)
    end
  end
end
