# SimpleFin Loan processor for loan-specific features
class SimplefinAccount::Liabilities::LoanProcessor
  def initialize(simplefin_account)
    @simplefin_account = simplefin_account
  end

  def process
    return unless simplefin_account.account&.accountable_type == "Loan"

    # Update loan specific attributes if available
    update_loan_attributes
  end

  private
    attr_reader :simplefin_account

    def account
      simplefin_account.account
    end

    def update_loan_attributes
      # I don't know if SimpleFin typically provide detailed loan metadata
      # like interest rates, terms, etc. but we can update what's available

      # Balance normalization is handled by SimplefinAccount::Processor.process_account!
      # Any other loan-specific attribute updates would go here
    end
end
