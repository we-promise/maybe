class MercuryConnection::Syncer < DirectBank::Syncer
  def initialize(connection)
    super(connection)
  end

  def perform_sync(sync)
    sync.update!(status: :syncing)

    Rails.logger.info "Starting Mercury sync for connection #{@connection.id}"

    # Refresh OAuth token if needed
    @connection.refresh_token_if_needed!

    # Import accounts and transactions
    DirectBank::Importer.new(@connection).import

    # Schedule account syncs
    @connection.schedule_account_syncs(
      parent_sync: sync,
      window_start_date: sync.window_start_date,
      window_end_date: sync.window_end_date
    )

    sync.update!(status: :completed, completed_at: Time.current)

    Rails.logger.info "Mercury sync completed for connection #{@connection.id}"
  rescue => e
    Rails.logger.error "Mercury sync failed: #{e.message}"
    sync.update!(status: :failed, error: e.message, failed_at: Time.current)
    raise
  end

  def perform_post_sync
    @connection.broadcast_sync_complete
  end
end
