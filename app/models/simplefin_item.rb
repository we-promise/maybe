class SimplefinItem < ApplicationRecord
  include Syncable, Provided

  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  # Virtual attribute for the setup token form field
  attr_accessor :setup_token

  if Rails.application.credentials.active_record_encryption.present?
    encrypts :access_url, deterministic: true
  end

  validates :name, :access_url, presence: true

  before_destroy :remove_simplefin_item

  belongs_to :family
  has_one_attached :logo

  has_many :simplefin_accounts, dependent: :destroy
  has_many :accounts, through: :simplefin_accounts

  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :needs_update, -> { where(status: :requires_update) }

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  def import_latest_simplefin_data
    SimplefinItem::Importer.new(self, simplefin_provider: simplefin_provider).import
  end

  def process_accounts
    simplefin_accounts.joins(:account).each do |simplefin_account|
      SimplefinAccount::Processor.new(simplefin_account).process
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

  def upsert_simplefin_snapshot!(accounts_snapshot)
    assign_attributes(
      raw_payload: accounts_snapshot,
    )

    # Extract institution data from the first account if available
    if accounts_snapshot[:accounts]&.any?
      first_account = accounts_snapshot[:accounts].first
      if first_account[:org].present?
        upsert_institution_data!(first_account[:org])
      end
    end

    save!
  end

  def upsert_institution_data!(org_data)
    assign_attributes(
      institution_id: org_data[:id],
      institution_name: org_data[:name],
      institution_domain: org_data[:domain],
      institution_url: org_data[:url] || org_data[:"sfin-url"],
      raw_institution_payload: org_data
    )
  end


  def has_completed_initial_setup?
    # Setup is complete if we have any linked accounts
    accounts.any?
  end

  def institution_display_name
    # Try to get institution name from stored metadata
    institution_name.presence || institution_domain.presence || name
  end

  def connected_institutions
    # Get unique institutions from all accounts
    simplefin_accounts.includes(:account)
                     .where.not(org_data: nil)
                     .map { |acc| acc.org_data }
                     .uniq { |org| org["domain"] || org["name"] }
  end

  def institution_summary
    institutions = connected_institutions
    case institutions.count
    when 0
      "No institutions connected"
    when 1
      institutions.first["name"] || institutions.first["domain"] || "1 institution"
    else
      "#{institutions.count} institutions"
    end
  end

  private
    def remove_simplefin_item
      # SimpleFin doesn't require server-side cleanup like Plaid
      # The access URL just becomes inactive
    end
end
