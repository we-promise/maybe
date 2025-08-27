class MercuryAccount < DirectBankAccount
  belongs_to :mercury_connection, foreign_key: :direct_bank_connection_id

  def connection
    mercury_connection
  end

  def sync_with_refresh
    connection.refresh_token_if_needed!
    sync_balance
    sync_transactions
  end
end
