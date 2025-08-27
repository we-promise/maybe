class CreateDirectBankTables < ActiveRecord::Migration[7.2]
  def change
    create_table :direct_bank_connections, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :type, null: false
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :credentials
      t.string :status, default: "good"
      t.jsonb :metadata
      t.boolean :scheduled_for_deletion, default: false
      t.boolean :pending_account_setup, default: false
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :direct_bank_connections, :type
    add_index :direct_bank_connections, :status
    add_index :direct_bank_connections, [ :family_id, :type ]

    create_table :direct_bank_accounts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :type, null: false
      t.references :direct_bank_connection, type: :uuid, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :currency, default: "USD"
      t.decimal :current_balance, precision: 19, scale: 4
      t.decimal :available_balance, precision: 19, scale: 4
      t.string :account_type
      t.string :account_subtype
      t.jsonb :raw_data
      t.datetime :balance_date

      t.timestamps
    end

    add_index :direct_bank_accounts, :type
    add_index :direct_bank_accounts, :external_id
    add_index :direct_bank_accounts, [ :direct_bank_connection_id, :external_id ], unique: true, name: "idx_direct_bank_accounts_connection_external"
  end
end
