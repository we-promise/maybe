class WiseConnection::Syncer < DirectBank::Syncer
  def initialize(connection)
    super(connection)
  end

  def perform_sync(sync)
    sync.update!(status: :syncing)

    Rails.logger.info "Starting Wise sync for connection #{@connection.id}"

    # Import profiles first if not already done
    @connection.import_profiles if @connection.metadata.nil? || @connection.metadata["profiles"].blank?

    # Import accounts and transactions
    DirectBank::Importer.new(@connection).import

    # Schedule account syncs
    @connection.schedule_account_syncs(
      parent_sync: sync,
      window_start_date: sync.window_start_date,
      window_end_date: sync.window_end_date
    )

    sync.update!(status: :completed, completed_at: Time.current)

    Rails.logger.info "Wise sync completed for connection #{@connection.id}"
  rescue => e
    Rails.logger.error "Wise sync failed: #{e.message}"
    sync.update!(status: :failed, error: e.message, failed_at: Time.current)
    raise
  end

  def perform_post_sync
    @connection.broadcast_sync_complete
  end
end
