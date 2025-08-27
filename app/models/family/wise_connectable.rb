module Family::WiseConnectable
  extend ActiveSupport::Concern

  included do
    has_many :wise_items, dependent: :destroy
  end

  def can_connect_wise?
    true # Wise is available globally
  end

  def create_wise_item!(api_key:, item_name: nil)
    wise_provider = Provider::Wise.new(api_key)

    # Test the API key by fetching profiles
    profiles = wise_provider.get_profiles

    if profiles.empty?
      raise ArgumentError, "No profiles found for this Wise account"
    end

    wise_item = wise_items.create!(
      name: item_name || "Wise Connection",
      api_key: api_key
    )

    wise_item.sync_later

    wise_item
  end
end
