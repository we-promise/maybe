class DirectBankConnection < ApplicationRecord
  include Syncable, Provided

  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  if Rails.application.credentials.active_record_encryption.present?
    encrypts :credentials
  end

  validates :name, presence: true

  belongs_to :family
  has_one_attached :logo

  has_many :direct_bank_accounts, dependent: :destroy, foreign_key: :direct_bank_connection_id
  has_many :accounts, through: :direct_bank_accounts

  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :needs_update, -> { where(status: :requires_update) }

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  def provider_class
    # Safe class lookup based on connection type
    DirectBankRegistry.provider_class(provider_type.downcase)
  end

  def provider
    @provider ||= provider_class.new(credentials)
  end

  def provider_type
    self.class.name.gsub("Connection", "")
  end

  def import_latest_data
    DirectBank::Importer.new(self).import
  end

  def process_accounts
    direct_bank_accounts.each do |bank_account|
      DirectBank::AccountProcessor.new(bank_account).process
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

  def validate_credentials!
    provider.validate_credentials
  end

  def authentication_type
    provider_class.authentication_type
  end
end
