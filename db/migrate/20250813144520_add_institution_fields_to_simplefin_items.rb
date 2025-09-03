class AddInstitutionFieldsToSimplefinItems < ActiveRecord::Migration[7.2]
  def up
    # Only add the new fields that don't already exist
    # institution_id, institution_name, institution_url, and raw_institution_payload
    # already exist from the original create_simplefin_items migration
    add_column :simplefin_items, :institution_domain, :string
    add_column :simplefin_items, :institution_color, :string

    # Add indexes for performance on commonly queried institution fields
    add_index :simplefin_items, :institution_id
    add_index :simplefin_items, :institution_domain
    add_index :simplefin_items, :institution_name

    # Enforce NOT NULL constraints on required fields
    change_column_null :simplefin_items, :institution_id, false
    change_column_null :simplefin_items, :institution_name, false
  end

  def down
    # Revert NOT NULL constraints
    change_column_null :simplefin_items, :institution_id, true
    change_column_null :simplefin_items, :institution_name, true

    # Remove indexes
    remove_index :simplefin_items, :institution_id
    remove_index :simplefin_items, :institution_domain
    remove_index :simplefin_items, :institution_name

    # Remove the new columns
    remove_column :simplefin_items, :institution_domain
    remove_column :simplefin_items, :institution_color
  end
end
