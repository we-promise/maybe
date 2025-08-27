module WiseItem::Provided
  extend ActiveSupport::Concern

  def wise_provider
    @wise_provider ||= Provider::Wise.new(api_key)
  end
end
