class MercuryConnection::SyncCompleteEvent
  def initialize(connection)
    @connection = connection
  end

  def broadcast
    # Broadcast sync complete event to Turbo Streams
    Turbo::StreamsChannel.broadcast_replace_to(
      @connection.family,
      target: "mercury_connection_#{@connection.id}_status",
      partial: "direct_banks/connection_status",
      locals: { connection: @connection }
    )
  end
end
