class CreateWiseAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :wise_accounts, id: :uuid do |t|
      t.references :wise_item, type: :uuid, null: false, foreign_key: true
      t.string :name
      t.string :account_id
      t.string :currency
      t.decimal :current_balance, precision: 19, scale: 4
      t.decimal :available_balance, precision: 19, scale: 4
      t.string :account_type
      t.jsonb :raw_payload
      t.jsonb :raw_transactions_payload
      t.datetime :balance_date

      t.timestamps
    end

    add_index :wise_accounts, :account_id
  end
end