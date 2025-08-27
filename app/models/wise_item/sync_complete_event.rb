class WiseItem::SyncCompleteEvent
  include Turbo::Broadcastable

  attr_reader :wise_item

  def initialize(wise_item)
    @wise_item = wise_item
  end

  def broadcast
    broadcast_replace_later_to(
      [ wise_item.family, :wise_items ],
      target: dom_target,
      partial: "wise_items/wise_item",
      locals: { wise_item: wise_item }
    )
  end

  private
    def dom_target
      "wise_item_#{wise_item.id}"
    end
end
