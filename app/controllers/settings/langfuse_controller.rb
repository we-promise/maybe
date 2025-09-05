class Settings::LangfuseController < ApplicationController
  def index
    @langfuse_enabled = ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?
    @langfuse_host = ENV["LANGFUSE_HOST"] || "https://cloud.langfuse.com"
  end

  def test_connection
    if ENV["LANGFUSE_PUBLIC_KEY"].blank? || ENV["LANGFUSE_SECRET_KEY"].blank?
      render json: { success: false, message: "Langfuse is not configured. Please set LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY environment variables." }
      return
    end

    begin
      # Try to create a simple test trace
      client = Langfuse.new
      trace = client.trace(name: "connection_test", input: { test: true })
      trace.update(output: { success: true })

      render json: { success: true, message: "Successfully connected to Langfuse!" }
    rescue => e
      render json: { success: false, message: "Failed to connect to Langfuse: #{e.message}" }
    end
  end

  def clear_logs
    # Add security checks here
    render json: { success: true, message: "Note: This doesn't actually clear logs in Langfuse. You would need to use the Langfuse UI or API to delete traces." }
  end
end
