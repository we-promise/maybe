module Account::WiseOpeningBalance
  extend ActiveSupport::Concern

  class_methods do
    def create_from_wise_account(wise_account, account_type, subtype = nil)
      # Get the statement data if available
      statement_data = wise_account.raw_payload&.dig("statement_data")

      # Determine the initial balance and date
      if statement_data && statement_data["opening_balance"]
        initial_balance = statement_data["opening_balance"]["value"] || 0
        # Parse the statement start date
        opening_date = if statement_data["statement_start_date"]
          Date.parse(statement_data["statement_start_date"]) - 1.day
        else
          nil
        end
      else
        initial_balance = wise_account.current_balance || 0
        opening_date = nil
      end

      # Get the current balance
      balance = wise_account.current_balance || 0

      attributes = {
        family: wise_account.wise_item.family,
        name: wise_account.name,
        balance: balance,
        currency: wise_account.currency,
        accountable_type: account_type,
        accountable_attributes: { subtype: subtype },
        wise_account_id: wise_account.id
      }

      # Create the account
      account = new(attributes.merge(cash_balance: attributes[:balance]))

      transaction do
        account.save!

        # Set the opening balance with the correct date if we have it
        manager = Account::OpeningBalanceManager.new(account)
        result = if opening_date
          # Use the actual opening balance and date from Wise
          manager.set_opening_balance(balance: initial_balance, date: opening_date)
        else
          # Fall back to default behavior
          manager.set_opening_balance(balance: initial_balance)
        end

        raise result.error if result.error
      end

      account.sync_later
      account
    end
  end
end