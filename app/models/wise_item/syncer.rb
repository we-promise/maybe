class WiseItem::Syncer
  attr_reader :wise_item

  def initialize(wise_item)
    @wise_item = wise_item
  end

  def perform_sync(sync)
    # Loads profiles, accounts, transactions from Wise API
    wise_item.import_latest_wise_data

    # Check if we have new Wise accounts that need setup
    unlinked_accounts = wise_item.wise_accounts.includes(:account).where(accounts: { id: nil })
    if unlinked_accounts.any?
      # Mark as pending account setup so user can choose account types
      wise_item.update!(pending_account_setup: true)
      return
    end

    # Processes the raw Wise data and updates internal domain objects
    wise_item.process_accounts

    # All data is synced, so we can now run an account sync to calculate historical balances and more
    wise_item.schedule_account_syncs(
      parent_sync: sync,
      window_start_date: sync.window_start_date,
      window_end_date: sync.window_end_date
    )
  end

  def perform_post_sync
    # no-op
  end
end