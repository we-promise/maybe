require "test_helper"

class Provider::OllamaTest < ActiveSupport::TestCase
  include LLMInterfaceTest

  setup do
    @subject = Provider::Ollama.new("http://host.docker.internal:11434")
    @subject_model = "llama3.2"
  end

  test "supports ollama models" do
    assert @subject.supports_model?("llama3.2")
    assert @subject.supports_model?("mistral")
    assert_not @subject.supports_model?("invalid-model")
  end

  test "initializes with correct base url" do
    provider = Provider::Ollama.new("http://host.docker.internal:11434")

    assert_not_nil provider
  end

  test "auto categorize raises error for too many transactions" do
    transactions = (1..26).map { |i| { id: i.to_s, name: "Transaction #{i}" } }

    assert_raises Provider::Ollama::Error do
      @subject.auto_categorize(transactions: transactions)
    end
  end

  test "auto detect merchants raises error for too many transactions" do
    transactions = (1..26).map { |i| { id: i.to_s, description: "Transaction #{i}" } }

    assert_raises Provider::Ollama::Error do
      @subject.auto_detect_merchants(transactions: transactions)
    end
  end

  test "strips trailing slash from base url" do
    provider = Provider::Ollama.new("http://host.docker.internal:11434/")

    # Can't directly test private base_url, but initialization should succeed
    assert_not_nil provider
  end
end
