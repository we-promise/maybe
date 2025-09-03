class FixHoldingsCostBasisAndExternalIdConstraints < ActiveRecord::Migration[7.2]
  def change
    change_column :holdings, :cost_basis, :decimal, precision: 19, scale: 4
    add_index :holdings, [ :account_id, :external_id ],
              unique: true,
              where: "external_id IS NOT NULL",
              name: "idx_holdings_on_account_id_external_id_unique"
  end
end
