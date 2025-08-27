class WiseItem < ApplicationRecord
  include Syncable, Provided

  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  attr_accessor :setup_api_key

  if Rails.application.credentials.active_record_encryption.present?
    encrypts :api_key, deterministic: true
  end

  validates :name, :api_key, presence: true

  before_destroy :remove_wise_item

  belongs_to :family
  has_one_attached :logo

  has_many :wise_accounts, dependent: :destroy
  has_many :accounts, through: :wise_accounts

  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :needs_update, -> { where(status: :requires_update) }

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  def import_latest_wise_data
    WiseItem::Importer.new(self, wise_provider: wise_provider).import
  end

  def process_accounts
    wise_accounts.each do |wise_account|
      WiseAccount::Processor.new(wise_account).process
    end
  end

  def schedule_account_syncs(parent_sync: nil, window_start_date: nil, window_end_date: nil)
    accounts.each do |account|
      account.sync_later(
        parent_sync: parent_sync,
        window_start_date: window_start_date,
        window_end_date: window_end_date
      )
    end
  end

  def upsert_wise_snapshot!(data)
    assign_attributes(raw_payload: data)
    save!
  end

  def upsert_wise_profiles_snapshot!(profiles_data)
    assign_attributes(raw_profiles_payload: profiles_data)

    # Store the first personal and business profile IDs for easy access
    personal_profile = profiles_data.find { |p| p[:type] == "personal" || p[:type] == "PERSONAL" }
    business_profile = profiles_data.find { |p| p[:type] == "business" || p[:type] == "BUSINESS" }

    assign_attributes(
      personal_profile_id: personal_profile&.dig(:id),
      business_profile_id: business_profile&.dig(:id),
      profile_id: personal_profile&.dig(:id) || business_profile&.dig(:id)
    )

    save!
  end

  private
    def remove_wise_item
      # Wise doesn't require server-side cleanup like Plaid
      # The API key just becomes inactive when removed
    end
end
