class DirectBank::SyncCompleteEvent
  attr_reader :connection

  def initialize(connection)
    @connection = connection
  end

  def publish
    broadcast_to_connection
    broadcast_to_family
  end

  private

    def broadcast_to_connection
      Turbo::StreamsChannel.broadcast_replace_to(
        @connection,
        target: "direct_bank_connection_#{@connection.id}",
        partial: "direct_banks/connection",
        locals: { connection: @connection }
      )
    end

    def broadcast_to_family
      Turbo::StreamsChannel.broadcast_append_to(
        [ @connection.family, "sync_events" ],
        target: "sync_events",
        partial: "shared/sync_event",
        locals: {
          message: "#{@connection.name} sync completed",
          timestamp: Time.current
        }
      )
    end
end
