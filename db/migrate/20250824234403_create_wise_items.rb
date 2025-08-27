class CreateWiseItems < ActiveRecord::Migration[7.2]
  def change
    create_table :wise_items, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.text :api_key
      t.string :profile_id
      t.string :name
      t.string :personal_profile_id
      t.string :business_profile_id
      t.string :status, default: "good"
      t.boolean :scheduled_for_deletion, default: false
      t.boolean :pending_account_setup, default: false, null: false
      t.jsonb :raw_payload
      t.jsonb :raw_profiles_payload

      t.timestamps
    end

    add_index :wise_items, :status
  end
end
