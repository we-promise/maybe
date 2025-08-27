class WiseAccount < DirectBankAccount
  belongs_to :wise_connection, foreign_key: :direct_bank_connection_id

  def connection
    wise_connection
  end

  def profile_id
    raw_data&.dig("profile_id")
  end

  def balance_id
    raw_data&.dig("balance_id")
  end
end
