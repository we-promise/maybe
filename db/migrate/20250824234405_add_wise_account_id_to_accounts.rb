class AddWiseAccountIdToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_reference :accounts, :wise_account, type: :uuid, foreign_key: true, index: true
  end
end