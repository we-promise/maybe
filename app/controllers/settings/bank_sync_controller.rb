class Settings::BankSyncController < ApplicationController
  layout "settings"

  def show
    @providers = build_provider_list
  end

  private

    def build_provider_list
      providers = []

      # Data aggregators
      providers << {
        name: "Lunch Flow",
        description: "US, Canada, UK, EU, Brazil and Asia through multiple open banking providers.",
        path: "https://lunchflow.app/features/sure-integration",
        target: "_blank",
        rel: "noopener noreferrer",
        type: :aggregator
      }

      providers << {
        name: "Plaid",
        description: "US & Canada bank connections with transactions, investments, and liabilities.",
        path: "https://github.com/we-promise/sure/blob/main/docs/hosting/plaid.md",
        target: "_blank",
        rel: "noopener noreferrer",
        type: :aggregator
      }

      providers << {
        name: "SimpleFin",
        description: "US & Canada connections via SimpleFin protocol.",
        path: simplefin_items_path,
        type: :aggregator
      }

      # Direct bank connections
      DirectBankRegistry.available_providers.each do |key, config|
        providers << {
          name: config[:name],
          description: config[:description],
          path: send("direct_bank_#{key}_index_path"),
          type: :direct_bank,
          auth_type: config[:auth_type]
        }
      end

      providers
    end
end
