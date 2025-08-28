# MCP (Model Context Protocol) Plan

This document outlines the Claude Code implementation plan for MCP (Model Context Protocol) in the Sure Finance application using the fast-mcp gem. MCP enables AI models to interact with Rails applications through a standardized protocol for tools and resources.

## Overview

The Model Context Protocol (MCP) provides a standardized way for AI models to interact with our application by:
- Exposing tools that AI can call to perform actions
- Providing resources that AI can query for information
- Supporting multiple transport protocols (STDIO, HTTP, SSE)

## Architecture

### Integration Approach

We use the Rack Middleware approach for MCP integration, which:
- Embeds MCP directly in the Rails application
- Simplifies deployment (no separate process management)
- Enables easy resource sharing with the Rails app
- Provides HTTP/SSE endpoints for AI interaction

### Directory Structure

```
app/
├── tools/           # MCP tool definitions
├── resources/       # MCP resource definitions
└── mcp/            # MCP-specific configurations and helpers

config/
└── initializers/
    └── fast_mcp.rb  # MCP server configuration
```

## Implementation Plan

### Phase 1: Basic Setup

1. **Install Dependencies**
   ```ruby
   # Gemfile
   gem "fast-mcp"
   ```
   ```bash
   bundle install
   bin/rails generate fast_mcp:install
   ```

2. **Configure MCP Server**
   ```ruby
   # config/initializers/fast_mcp.rb
   FastMcp.configure do |config|
     config.server_name = "Sure Finance MCP"
     config.server_version = "1.0.0"
     config.description = "AI-powered financial management tools"
     
     # Enable authentication
     config.authenticate = true
     config.auth_strategy = :api_key
     
     # Configure transport
     config.transport = :http
     config.mount_path = "/mcp"
   end
   ```

### Phase 2: Financial Tools Implementation

#### Account Management Tools

1. **FetchAccountsBalanceTool**
   ```ruby
   # app/tools/fetch_accounts_balance_tool.rb
   class FetchAccountsBalanceTool < FastMcp::Tool
     description "Fetch current balances for all accounts or specific account"
     
     arguments do
       optional(:account_id).filled(:string)
       optional(:account_type).filled(:string)
     end
     
     def call(account_id: nil, account_type: nil)
       scope = Current.family.accounts
       scope = scope.where(id: account_id) if account_id
       scope = scope.where(accountable_type: account_type) if account_type
       
       accounts = scope.includes(:accountable).map do |account|
         {
           id: account.id,
           name: account.name,
           type: account.accountable_type,
           balance: account.balance.to_f,
           currency: account.currency
         }
       end
       
       { accounts: accounts, total_balance: accounts.sum { |a| a[:balance] } }
     end
   end
   ```

2. **AnalyzeSpendingTool**
   ```ruby
   # app/tools/analyze_spending_tool.rb
   class AnalyzeSpendingTool < FastMcp::Tool
     description "Analyze spending patterns for a given time period"
     
     arguments do
       optional(:period).filled(:string).value(included_in?: %w[day week month year])
       optional(:category_id).filled(:string)
     end
     
     def call(period: "month", category_id: nil)
       transactions = Current.family.transactions
                            .expense
                            .where(date: period_range(period))
       
       transactions = transactions.where(category_id: category_id) if category_id
       
       by_category = transactions.joins(:category)
                                .group("categories.name")
                                .sum(:amount)
       
       {
         total_spent: transactions.sum(:amount).to_f,
         by_category: by_category.transform_values(&:to_f),
         transaction_count: transactions.count,
         average_transaction: (transactions.average(:amount) || 0).to_f
       }
     end
     
     private
     
     def period_range(period)
       case period
       when "day" then Date.current.beginning_of_day..Date.current.end_of_day
       when "week" then Date.current.beginning_of_week..Date.current.end_of_week
       when "month" then Date.current.beginning_of_month..Date.current.end_of_month
       when "year" then Date.current.beginning_of_year..Date.current.end_of_year
       end
     end
   end
   ```

3. **CreateTransactionTool**
   ```ruby
   # app/tools/create_transaction_tool.rb
   class CreateTransactionTool < FastMcp::Tool
     description "Create a new transaction"
     
     arguments do
       required(:account_id).filled(:string)
       required(:amount).filled(:float)
       required(:name).filled(:string)
       required(:date).filled(:string)
       optional(:category_id).filled(:string)
       optional(:notes).filled(:string)
     end
     
     def call(account_id:, amount:, name:, date:, category_id: nil, notes: nil)
       account = Current.family.accounts.find(account_id)
       
       transaction = account.transactions.create!(
         amount: amount,
         name: name,
         date: Date.parse(date),
         category_id: category_id,
         notes: notes
       )
       
       {
         success: true,
         transaction: {
           id: transaction.id,
           name: transaction.name,
           amount: transaction.amount.to_f,
           date: transaction.date.to_s
         }
       }
     rescue => e
       { success: false, error: e.message }
     end
   end
   ```

### Phase 3: Financial Resources Implementation

1. **AccountSummaryResource**
   ```ruby
   # app/resources/account_summary_resource.rb
   class AccountSummaryResource < FastMcp::Resource
     uri "finance/account-summary"
     resource_name "Account Summary"
     description "Current financial overview including all accounts and balances"
     mime_type "application/json"
     
     def content
       summary = {
         total_assets: Current.family.assets.sum(:balance).to_f,
         total_liabilities: Current.family.liabilities.sum(:balance).to_f,
         net_worth: Current.family.net_worth.to_f,
         accounts_by_type: Current.family.accounts
                                 .group(:accountable_type)
                                 .sum(:balance)
                                 .transform_values(&:to_f),
         last_updated: Time.current.iso8601
       }
       
       JSON.generate(summary)
     end
   end
   ```

2. **BudgetStatusResource**
   ```ruby
   # app/resources/budget_status_resource.rb
   class BudgetStatusResource < FastMcp::Resource
     uri "finance/budget-status"
     resource_name "Budget Status"
     description "Current month budget status and spending"
     mime_type "application/json"
     
     def content
       # Implement budget tracking logic
       budget_data = {
         month: Date.current.strftime("%B %Y"),
         categories: calculate_budget_by_category,
         total_budgeted: 5000.0, # Example
         total_spent: calculate_total_spent,
         remaining: calculate_remaining_budget
       }
       
       JSON.generate(budget_data)
     end
     
     private
     
     def calculate_budget_by_category
       # Implementation details
     end
     
     def calculate_total_spent
       Current.family.transactions
              .expense
              .where(date: Date.current.beginning_of_month..Date.current.end_of_month)
              .sum(:amount).to_f
     end
     
     def calculate_remaining_budget
       # Implementation details
     end
   end
   ```

### Phase 4: Server Registration

```ruby
# config/initializers/fast_mcp.rb (extended)
Rails.application.config.after_initialize do
  # Register tools
  FastMcp.server.register_tool(FetchAccountsBalanceTool)
  FastMcp.server.register_tool(AnalyzeSpendingTool)
  FastMcp.server.register_tool(CreateTransactionTool)
  
  # Register resources
  FastMcp.server.register_resource(AccountSummaryResource)
  FastMcp.server.register_resource(BudgetStatusResource)
  
  # Mount middleware
  Rails.application.routes.draw do
    mount FastMcp.server => "/mcp"
  end
end
```

## Usage Examples

### Using with Claude Desktop

1. Configure Claude Desktop's MCP settings:
   ```json
   {
     "mcpServers": {
       "sure-finance": {
         "url": "http://localhost:3000/mcp",
         "apiKey": "your-api-key-here"
       }
     }
   }
   ```

2. Example interactions:
   ```
   User: "What's my current account balance?"
   Claude: [Uses FetchAccountsBalanceTool to retrieve balances]
   
   User: "How much did I spend on groceries this month?"
   Claude: [Uses AnalyzeSpendingTool with category filter]
   
   User: "Add a transaction for $45.99 at the grocery store"
   Claude: [Uses CreateTransactionTool to create the transaction]
   ```

### Using with API Clients

```ruby
# Example Ruby client
require 'faraday'
require 'json'

client = Faraday.new(url: 'http://localhost:3000/mcp') do |f|
  f.headers['Authorization'] = "Bearer #{api_key}"
  f.headers['Content-Type'] = 'application/json'
end

# Call a tool
response = client.post('/tools/execute') do |req|
  req.body = {
    tool: 'FetchAccountsBalanceTool',
    arguments: { account_type: 'Checking' }
  }.to_json
end

result = JSON.parse(response.body)
```

## Security Considerations

1. **Authentication**: All MCP endpoints require authentication via API key
2. **Authorization**: Tools respect Current.user and Current.family context
3. **Input Validation**: Dry-Schema validates all tool arguments
4. **Rate Limiting**: Inherits from application's Rack::Attack configuration

## Testing

```ruby
# test/mcp/tools/fetch_accounts_balance_tool_test.rb
require "test_helper"

class FetchAccountsBalanceToolTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
    @family = @user.family
    Current.user = @user
    Current.family = @family
  end
  
  test "fetches all account balances" do
    tool = FetchAccountsBalanceTool.new
    result = tool.call
    
    assert_equal @family.accounts.count, result[:accounts].size
    assert result[:total_balance].positive?
  end
  
  test "filters by account type" do
    tool = FetchAccountsBalanceTool.new
    result = tool.call(account_type: "Checking")
    
    assert result[:accounts].all? { |a| a[:type] == "Checking" }
  end
end
```

## Monitoring and Debugging

1. **Logging**: All MCP requests logged to Rails.logger
2. **Testing Tools**: Use MCP Inspector for debugging
   ```bash
   npx @modelcontextprotocol/inspector bin/rails runner "FastMcp.server.start"
   ```

3. **Performance Monitoring**: Integrate with existing Skylight/Sentry setup

## Future Enhancements

1. **Advanced Tools**
   - Investment portfolio analysis
   - Tax calculation assistance
   - Financial goal tracking
   - Automated categorization

2. **Real-time Updates**
   - WebSocket support for live data
   - Push notifications for AI insights

3. **Multi-user Support**
   - Family member context switching
   - Permission-based tool access

## References

- [Fast-MCP GitHub Repository](https://github.com/yjacquin/fast-mcp)
- [Model Context Protocol Specification](https://modelcontextprotocol.io)
- [Fast-MCP Documentation](https://rubydoc.info/gems/fast-mcp)