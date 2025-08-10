require "langfuse"

if ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
  Langfuse.configure do |config|
    config.public_key = ENV["LANGFUSE_PUBLIC_KEY"]
    config.secret_key = ENV["LANGFUSE_SECRET_KEY"]
    config.host = ENV["LANGFUSE_HOST"] if ENV["LANGFUSE_HOST"].present?
  end
end
