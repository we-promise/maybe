class AddUniqueIndexToHoldingsExternalId < ActiveRecord::Migration[7.2]
  def change
    add_index :holdings, [ :account_id, :external_id ], unique: true, name: 'index_holdings_on_account_and_external_id'
  end
end
