module Family::DirectBankConnectable
  extend ActiveSupport::Concern

  included do
    has_many :direct_bank_connections, dependent: :destroy
    has_many :mercury_connections
    has_many :wise_connections
  end

  def can_connect_direct_bank?(provider_key)
    DirectBankRegistry.supports_region?(provider_key)
  end

  def create_mercury_connection!(credentials)
    create_direct_bank_connection!(:mercury, credentials)
  end

  def create_wise_connection!(credentials)
    create_direct_bank_connection!(:wise, credentials)
  end

  def create_direct_bank_connection!(provider_type, credentials)
    connection_class = DirectBankRegistry.connection_class(provider_type)
    provider_class = DirectBankRegistry.provider_class(provider_type)

    raise ArgumentError, "Invalid provider: #{provider_type}" unless connection_class && provider_class

    provider = provider_class.new(credentials)
    provider.validate_credentials

    connection = connection_class.create!(
      family: self,
      credentials: credentials,
      name: "#{provider_type.to_s.humanize} Connection"
    )

    connection.sync_later
    connection
  rescue Provider::DirectBank::Base::DirectBankError => e
    raise ArgumentError, e.message
  end

  def direct_bank_connections_by_provider(provider_type)
    connection_class = DirectBankRegistry.connection_class(provider_type)
    return DirectBankConnection.none unless connection_class

    direct_bank_connections.where(type: connection_class.name)
  end
end
