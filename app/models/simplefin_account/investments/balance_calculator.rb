# SimpleFin Investment balance calculator
# SimpleFin provides clear balance and holdings data, so calculations are simpler than Plaid
class SimplefinAccount::Investments::BalanceCalculator
  def initialize(simplefin_account)
    @simplefin_account = simplefin_account
  end

  def balance
    # SimpleFin provides direct balance data
    simplefin_account.current_balance || BigDecimal("0")
  end

  def cash_balance
    # Calculate cash balance as total balance minus holdings value
    total_balance = balance
    holdings_value = total_holdings_value

    cash = total_balance - holdings_value

    # Ensure non-negative cash balance
    [ cash, 0 ].max
  end

  private
    attr_reader :simplefin_account

    def total_holdings_value
      return 0 unless simplefin_account.raw_payload&.dig("holdings")

      holdings_data = simplefin_account.raw_payload["holdings"]

      holdings_data.sum do |holding|
        market_value = holding["market_value"]
        case market_value
        when String
          BigDecimal(market_value)
        when Numeric
          BigDecimal(market_value.to_s)
        else
          BigDecimal("0")
        end
      end
    rescue ArgumentError => e
      Rails.logger.error "Failed to calculate SimpleFin holdings value: #{e.message}"
      0
    end
end
