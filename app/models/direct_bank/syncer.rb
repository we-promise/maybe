class DirectBank::Syncer
  def initialize(connection, parent_sync: nil)
    @connection = connection
    @parent_sync = parent_sync
    @provider = connection.provider
  end

  def sync
    @parent_sync&.update!(state: :syncing)

    Rails.logger.info "Starting sync for #{@connection.class.name} #{@connection.id}"

    DirectBank::Importer.new(@connection).import

    @connection.schedule_account_syncs(parent_sync: @parent_sync)

    @parent_sync&.update!(state: :completed)

    broadcast_sync_complete
  rescue => e
    Rails.logger.error "Sync failed for #{@connection.class.name} #{@connection.id}: #{e.message}"
    @parent_sync&.update!(state: :failed, error: e.message)
    raise
  end

  private

    def broadcast_sync_complete
      DirectBank::SyncCompleteEvent.new(@connection).publish
    end
end
