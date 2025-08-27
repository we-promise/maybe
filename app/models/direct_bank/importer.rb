class DirectBank::Importer
  def initialize(connection)
    @connection = connection
    @provider = connection.provider
  end

  def import
    Rails.logger.info "Importing data for #{@connection.class.name} #{@connection.id}"

    import_accounts
    @connection.update!(last_synced_at: Time.current, status: :good)
    @connection.process_accounts
  rescue Provider::DirectBank::Base::DirectBankError => e
    handle_provider_error(e)
  rescue => e
    Rails.logger.error "Import failed for #{@connection.class.name} #{@connection.id}: #{e.message}"
    @connection.update!(status: :requires_update)
    raise
  end

  private

    def import_accounts
      accounts_data = @provider.get_accounts

      accounts_data.each do |account_data|
        bank_account = @connection.direct_bank_accounts.find_or_initialize_by(
          external_id: account_data[:external_id]
        )

        bank_account.update!(
          name: account_data[:name],
          currency: account_data[:currency],
          account_type: account_data[:account_type],
          current_balance: account_data[:current_balance],
          available_balance: account_data[:available_balance],
          raw_data: account_data[:raw_data],
          balance_date: Time.current
        )
      end

      @connection.update!(pending_account_setup: has_unconnected_accounts?)
    end

    def has_unconnected_accounts?
      @connection.direct_bank_accounts.disconnected.any?
    end

    def handle_provider_error(error)
      Rails.logger.error "Provider error for #{@connection.class.name} #{@connection.id}: #{error.message}"

      case error.error_type
      when :authentication_failed
        @connection.update!(status: :requires_update)
      when :rate_limited
        Rails.logger.info "Rate limited, will retry later"
      else
        @connection.update!(status: :requires_update)
      end

      raise error
    end
end
