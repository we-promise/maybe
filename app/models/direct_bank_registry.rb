class DirectBankRegistry
  PROVIDERS = {
    wise: {
      name: "Wise",
      class_name: "Provider::DirectBank::Wise",
      connection_class: "WiseConnection",
      auth_type: :api_key,
      supported_regions: :global,
      features: [ :multi_currency, :business_accounts ],
      description: "Connect your Wise multi-currency accounts",
      setup_instructions: "Get your API key from Wise Settings > API tokens",
      icon: "wise",
      enabled: true
    },
    mercury: {
      name: "Mercury",
      class_name: "Provider::DirectBank::Mercury",
      connection_class: "MercuryConnection",
      auth_type: :oauth,
      supported_regions: [ :us ],
      features: [ :business_accounts, :treasury ],
      description: "Connect your Mercury business banking accounts",
      setup_instructions: "Authorize access to your Mercury account",
      icon: "mercury",
      enabled: true
    }
  }.freeze

  class << self
    def available_providers
      PROVIDERS.select { |_, config| provider_enabled?(config) }
    end

    def provider_config(provider_key)
      PROVIDERS[provider_key.to_sym]
    end

    def provider_class(provider_key)
      config = provider_config(provider_key)
      return nil unless config

      # Safe class lookup using predefined mapping
      case provider_key.to_sym
      when :mercury
        Provider::DirectBank::Mercury
      when :wise
        Provider::DirectBank::Wise
      else
        nil
      end
    end

    def connection_class(provider_key)
      config = provider_config(provider_key)
      return nil unless config

      # Safe class lookup using predefined mapping
      case provider_key.to_sym
      when :mercury
        MercuryConnection
      when :wise
        WiseConnection
      else
        nil
      end
    end

    def auth_type(provider_key)
      config = provider_config(provider_key)
      config&.fetch(:auth_type, nil)
    end

    def supports_region?(provider_key, region = :us)
      config = provider_config(provider_key)
      return false unless config

      supported_regions = config[:supported_regions]
      supported_regions == :global || supported_regions&.include?(region)
    end

    def provider_features(provider_key)
      config = provider_config(provider_key)
      config&.fetch(:features, [])
    end

    private

      def provider_enabled?(config)
        return false unless config[:enabled]

        if config[:supported_regions] != :global
          config[:supported_regions]&.include?(current_region)
        else
          true
        end
      end

      def current_region
        ENV.fetch("APP_REGION", "us").to_sym
      end
  end
end
