class SimplefinItem::Importer
  attr_reader :simplefin_item, :simplefin_provider

  def initialize(simplefin_item, simplefin_provider:)
    @simplefin_item = simplefin_item
    @simplefin_provider = simplefin_provider
  end

  def import
    # Determine start date based on sync history
    start_date = determine_sync_start_date

    begin
      accounts_data = simplefin_provider.get_accounts(
        simplefin_item.access_url,
        start_date: start_date
      )
    rescue Provider::Simplefin::SimplefinError => e
      # Handle authentication errors by marking item as requiring update
      if e.error_type == :access_forbidden
        simplefin_item.update!(status: :requires_update)
        raise e
      else
        raise e
      end
    end

    # Handle errors if present in response
    if accounts_data[:errors] && accounts_data[:errors].any?
      handle_errors(accounts_data[:errors])
      return
    end

    # Store raw payload
    simplefin_item.upsert_simplefin_snapshot!(accounts_data)

    # Import accounts
    accounts_data[:accounts]&.each do |account_data|
      import_account(account_data)
    end
  end

  private

    def determine_sync_start_date
      # For the first sync, get only 1 month of data by using a narrow date range
      # SimpleFin requires a start_date parameter - without it, only returns recent transactions
      unless simplefin_item.last_synced_at
        return 1.month.ago
      end

      # For subsequent syncs, fetch from last sync date with a buffer
      # Use 7 days buffer to ensure we don't miss any late-posting transactions
      simplefin_item.last_synced_at - 7.days
    end

    def import_account(account_data)
      account_id = account_data[:id]

      # Validate required account_id to prevent duplicate creation
      return if account_id.blank?

      simplefin_account = simplefin_item.simplefin_accounts.find_or_initialize_by(
        account_id: account_id
      )

      # Store transactions separately from account data to avoid overwriting
      transactions = account_data[:transactions]

      # Update all attributes including transactions
      simplefin_account.assign_attributes(
        name: account_data[:name],
        account_type: account_data["type"] || account_data[:type] || "unknown",
        currency: account_data[:currency] || "USD",
        current_balance: account_data[:balance],
        available_balance: account_data[:"available-balance"],
        balance_date: account_data[:"balance-date"],
        raw_payload: account_data,
        raw_transactions_payload: transactions || [],
        org_data: account_data[:org]
      )

      # Final validation before save to prevent duplicates
      if simplefin_account.account_id.blank?
        simplefin_account.account_id = account_id
      end

      simplefin_account.save!
    end


    def handle_errors(errors)
      error_messages = errors.map { |error| error.is_a?(String) ? error : (error[:description] || error[:message]) }.join(", ")

      # Mark item as requiring update for authentication-related errors
      needs_update = errors.any? do |error|
        if error.is_a?(String)
          error.downcase.include?("reauthenticate") || error.downcase.include?("authentication")
        else
          error[:code] == "auth_failure" || error[:code] == "token_expired" ||
          error[:type] == "authentication_error"
        end
      end

      if needs_update
        simplefin_item.update!(status: :requires_update)
      end

      raise Provider::Simplefin::SimplefinError.new(
        "SimpleFin API errors: #{error_messages}",
        :api_error
      )
    end
end
