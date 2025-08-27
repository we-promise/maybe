class MakeDirectBankAccountTypeNullable < ActiveRecord::Migration[7.2]
  def change
    change_column_null :direct_bank_accounts, :type, true
    change_column_default :direct_bank_accounts, :type, 'DirectBankAccount'
  end
end
