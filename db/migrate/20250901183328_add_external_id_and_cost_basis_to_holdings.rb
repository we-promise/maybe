class AddExternalIdAndCostBasisToHoldings < ActiveRecord::Migration[7.2]
  def change
    add_column :holdings, :external_id, :string
    add_column :holdings, :cost_basis, :decimal
  end
end
