# frozen_string_literal: true

class FetchAccountsBalanceTool < ApplicationTool
  def call(account_type: nil)
    family = Current.family
    return { error: "No family found" } unless family

    accounts = family.accounts
    accounts = accounts.where(accountable_type: account_type) if account_type.present?

    account_data = accounts.map do |account|
      {
        id: account.id,
        name: account.name,
        type: account.accountable_type,
        balance: account.balance.to_f
      }
    end

    total_balance = accounts.sum(&:balance).to_f

    {
      accounts: account_data,
      total_balance: total_balance
    }
  end
end
