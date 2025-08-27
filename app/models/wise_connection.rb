class WiseConnection < DirectBankConnection
  validates :credentials, presence: true
  validate :validate_api_key

  def provider
    @provider ||= Provider::DirectBank::Wise.new(credentials)
  end

  def import_profiles
    profiles = provider.get_profiles

    update!(metadata: (metadata || {}).merge(
      profiles: profiles,
      personal_profile_id: profiles.find { |p| p[:type] == "personal" }&.dig(:id),
      business_profile_id: profiles.find { |p| p[:type] == "business" }&.dig(:id)
    ))
  end

  private

    def validate_api_key
      return if credentials.blank?

      unless credentials["api_key"].present?
        errors.add(:credentials, "must include API key")
      end
    end
end
