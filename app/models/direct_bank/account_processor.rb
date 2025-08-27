class DirectBank::AccountProcessor
  def initialize(bank_account)
    @bank_account = bank_account
    @connection = bank_account.direct_bank_connection
  end

  def process
    return unless @bank_account.connected?

    sync_balance
    sync_transactions
  rescue => e
    Rails.logger.error "Failed to process account #{@bank_account.id}: #{e.message}"
    raise
  end

  private

    def sync_balance
      @bank_account.sync_balance
    end

    def sync_transactions(start_date: nil, end_date: nil)
      @bank_account.sync_transactions(
        start_date: start_date || 30.days.ago,
        end_date: end_date || Date.current
      )
    end
end
