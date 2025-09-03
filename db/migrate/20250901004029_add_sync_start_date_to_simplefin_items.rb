class AddSyncStartDateToSimplefinItems < ActiveRecord::Migration[7.2]
  def change
    add_column :simplefin_items, :sync_start_date, :date
  end
end
