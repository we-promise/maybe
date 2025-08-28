class IncreaseTradePricePrecision < ActiveRecord::Migration[7.2]
  def up
    change_column :trades, :price, :decimal, precision: 19, scale: 10
  end

  def down
    change_column :trades, :price, :decimal, precision: 19, scale: 4
  end
end
