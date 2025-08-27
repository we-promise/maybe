class SimplefinAccount::Processor
  attr_reader :simplefin_account

  def initialize(simplefin_account)
    @simplefin_account = simplefin_account
  end

  # Each step represents different SimpleFin data processing
  # Processing the account is the first step and if it fails, we halt
  # Each subsequent step can fail independently, but we continue processing
  def process
    unless simplefin_account.account.present?
      return
    end

    process_account!
    process_transactions
    process_investments
    process_liabilities
  end

  private

    def process_account!
      # This should not happen in normal flow since accounts are created manually
      # during setup, but keeping as safety check
      if simplefin_account.account.blank?
        Rails.logger.error("SimpleFin account #{simplefin_account.id} has no associated Account - this should not happen after manual setup")
        return
      end

      # Update account balance and cash balance from latest SimpleFin data
      account = simplefin_account.account
      balance = simplefin_account.current_balance || simplefin_account.available_balance || 0

      # SimpleFin returns negative balances for credit cards (liabilities)
      # But Maybe expects positive balances for liabilities
      if account.accountable_type == "CreditCard" || account.accountable_type == "Loan"
        balance = balance.abs
      end

      # Calculate cash balance correctly for investment accounts
      cash_balance = if account.accountable_type == "Investment"
        calculator = SimplefinAccount::Investments::BalanceCalculator.new(simplefin_account)
        calculator.cash_balance
      else
        balance
      end

      account.update!(
        balance: balance,
        cash_balance: cash_balance
      )
    end

    def process_transactions
      SimplefinAccount::Transactions::Processor.new(simplefin_account).process
    rescue => e
      report_exception(e, "transactions")
    end

    def process_investments
      return unless simplefin_account.account&.accountable_type == "Investment"
      SimplefinAccount::Investments::TransactionsProcessor.new(simplefin_account).process
      SimplefinAccount::Investments::HoldingsProcessor.new(simplefin_account).process
    rescue => e
      report_exception(e, "investments")
    end

    def process_liabilities
      case simplefin_account.account&.accountable_type
      when "CreditCard"
        SimplefinAccount::Liabilities::CreditProcessor.new(simplefin_account).process
      when "Loan"
        SimplefinAccount::Liabilities::LoanProcessor.new(simplefin_account).process
      end
    rescue => e
      report_exception(e, "liabilities")
    end

    def report_exception(error, context)
      Sentry.capture_exception(error) do |scope|
        scope.set_tags(
          simplefin_account_id: simplefin_account.id,
          context: context
        )
      end
    end
end
