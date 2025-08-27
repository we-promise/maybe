class WiseAccount < ApplicationRecord
  belongs_to :wise_item
  has_one :account, dependent: :nullify

  validates :account_id, presence: true, uniqueness: { scope: :wise_item_id }

  def upsert_wise_snapshot!(account_data)
    data = account_data.with_indifferent_access

    # Extract balance information
    amount = data[:amount] || {}

    assign_attributes(
      name: build_account_name(data),
      currency: amount[:currency] || data[:currency],
      current_balance: amount[:value],
      available_balance: amount[:value], # Wise doesn't distinguish between current and available
      account_type: determine_account_type(data),
      balance_date: Time.current,
      raw_payload: account_data
    )

    save!
  end

  private

    def build_account_name(data)
      amount = data[:amount] || {}
      currency = amount[:currency] || data[:currency]

      if data[:name].present?
        data[:name]
      elsif currency.present?
        "Wise #{currency} Account"
      else
        "Wise Account"
      end
    end

    def determine_account_type(data)
      # Wise accounts are typically multi-currency wallets
      # We'll treat them as checking accounts for simplicity
      "checking"
    end
end
