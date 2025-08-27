class DirectBank::OpeningBalanceCreator
  def initialize(account, balance_amount)
    @account = account
    @balance_amount = balance_amount.to_d
  end

  def create
    return if @balance_amount.zero?

    opening_balance_date = 30.days.ago.to_date

    @account.entries.create!(
      entryable: Transaction.new(
        category: opening_balance_category,
        kind: :one_time  # Opening balance is a one-time transaction
      ),
      date: opening_balance_date,
      amount: @balance_amount,
      name: "Opening Balance",
      currency: @account.currency
    )

    @account.update!(balance: @balance_amount)
  end

  private

    def opening_balance_category
      @account.family.categories.find_or_create_by(
        name: "Opening Balance"
      ) do |category|
        category.color = "#6b7280"  # Gray color for system categories
      end
    end
end
