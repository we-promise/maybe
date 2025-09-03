class AddSyncStatsToSyncs < ActiveRecord::Migration[7.2]
  def change
    add_column :syncs, :sync_stats, :text
  end
end
