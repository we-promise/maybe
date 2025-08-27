class SimplefinItem::Syncer
  attr_reader :simplefin_item

  def initialize(simplefin_item)
    @simplefin_item = simplefin_item
  end

  def perform_sync(sync)
    # Phase 1: Import data from SimpleFin API
    sync.update!(status_text: "Importing accounts from SimpleFin...") if sync.respond_to?(:status_text)
    simplefin_item.import_latest_simplefin_data

    # Phase 2: Check account setup status
    sync.update!(status_text: "Checking account configuration...") if sync.respond_to?(:status_text)
    unlinked_accounts = simplefin_item.simplefin_accounts.includes(:account).where(accounts: { id: nil })

    # Set pending_account_setup if there are unlinked accounts
    if unlinked_accounts.any?
      simplefin_item.update!(pending_account_setup: true)
      sync.update!(status_text: "Waiting for account setup...") if sync.respond_to?(:status_text)
      return
    else
      simplefin_item.update!(pending_account_setup: false)
    end

    # Phase 3: Process transactions and holdings
    sync.update!(status_text: "Processing transactions and holdings...") if sync.respond_to?(:status_text)
    simplefin_item.process_accounts

    # Phase 4: Schedule balance calculations
    sync.update!(status_text: "Calculating balances...") if sync.respond_to?(:status_text)
    simplefin_item.schedule_account_syncs(
      parent_sync: sync,
      window_start_date: sync.window_start_date,
      window_end_date: sync.window_end_date
    )
  end

  def perform_post_sync
    # no-op
  end
end
