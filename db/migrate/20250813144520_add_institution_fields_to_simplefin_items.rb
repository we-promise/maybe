class AddInstitutionFieldsToSimplefinItems < ActiveRecord::Migration[7.2]
  def change
    add_column :simplefin_items, :institution_id, :string
    add_column :simplefin_items, :institution_name, :string
    add_column :simplefin_items, :institution_domain, :string
    add_column :simplefin_items, :institution_url, :string
    add_column :simplefin_items, :institution_color, :string
    add_column :simplefin_items, :raw_institution_payload, :jsonb
  end
end
