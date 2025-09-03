class AddRawHoldingsPayloadToSimplefinAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :simplefin_accounts, :raw_holdings_payload, :jsonb
  end
end
