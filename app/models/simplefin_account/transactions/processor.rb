class SimplefinAccount::Transactions::Processor
  attr_reader :simplefin_account

  def initialize(simplefin_account)
    @simplefin_account = simplefin_account
  end

  def process
    return unless simplefin_account.raw_transactions_payload.present?

    # Each entry is processed inside a transaction, but to avoid locking up the DB when
    # there are hundreds or thousands of transactions, we process them individually.
    simplefin_account.raw_transactions_payload.each do |transaction_data|
      SimplefinEntry::Processor.new(
        transaction_data,
        simplefin_account: simplefin_account
      ).process
    rescue => e
      Rails.logger.error "Error processing SimpleFin transaction: #{e.message}"
    end
  end

  private

    def category_matcher
      @category_matcher ||= SimplefinAccount::Transactions::CategoryMatcher.new(family_categories)
    end

    def family_categories
      @family_categories ||= begin
        if account.family.categories.none?
          account.family.categories.bootstrap!
        end

        account.family.categories
      end
    end

    def account
      simplefin_account.account
    end
end
