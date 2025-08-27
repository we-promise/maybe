class RemoveInstitutionFieldsFromSimplefinItems < ActiveRecord::Migration[7.2]
  def change
    remove_column :simplefin_items, :institution_id, :string
    remove_column :simplefin_items, :institution_name, :string
    remove_column :simplefin_items, :institution_url, :string
    remove_column :simplefin_items, :raw_institution_payload, :jsonb
  end
end
