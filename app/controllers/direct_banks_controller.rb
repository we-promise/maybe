class DirectBanksController < ApplicationController
  before_action :set_provider_type
  before_action :set_connection, only: [ :show, :destroy, :sync, :setup_accounts, :complete_account_setup ]

  def index
    @connections = Current.family.direct_bank_connections
                          .where(type: connection_class.name)
                          .active
                          .ordered
    render layout: "settings"
  end

  def show
  end

  def new
    @connection = connection_class.new
  end

  def create
    begin
      @connection = create_connection_safely
      redirect_to send("direct_bank_#{@provider_type}_path", @connection),
                  notice: "#{@provider_config[:name]} connection added successfully! Your accounts will appear shortly."
    rescue ArgumentError => e
      render_error(e.message)
    rescue Provider::DirectBank::Base::DirectBankError => e
      render_error(format_provider_error(e))
    rescue => e
      Rails.logger.error("#{@provider_config[:name]} connection error: #{e.message}")
      render_error("An unexpected error occurred. Please try again or contact support.")
    end
  end

  def destroy
    @connection.destroy_later
    redirect_to send("direct_bank_#{@provider_type}_index_path"), notice: "#{@provider_config[:name]} connection will be removed"
  end

  def sync
    @connection.sync_later
    redirect_to send("direct_bank_#{@provider_type}_path", @connection), notice: "Sync started"
  end

  def setup_accounts
    @bank_accounts = @connection.direct_bank_accounts.disconnected
    @account_type_options = [
      [ "Checking Account", "Depository", "checking" ],
      [ "Savings Account", "Depository", "savings" ],
      [ "Credit Card", "Credit", "credit_card" ],
      [ "Skip - don't add", "Skip", nil ]
    ]
  end

  def complete_account_setup
    setup_params = params.require(:accounts).to_unsafe_h

    setup_params.each do |account_id, config|
      config = config.slice(:account_type, :subtype, :balance)
      next if config[:account_type] == "Skip"

      bank_account = @connection.direct_bank_accounts.find(account_id)
      next if bank_account.connected?

      account = Current.family.accounts.create!(
        name: bank_account.name,
        accountable: bank_account,
        balance: bank_account.current_balance || 0,
        currency: bank_account.currency,
        subtype: config[:subtype]
      )

      if config[:balance].present?
        DirectBank::OpeningBalanceCreator.new(account, config[:balance]).create
      end
    end

    @connection.update!(pending_account_setup: false)
    @connection.sync_later

    redirect_to accounts_path, notice: "Accounts have been set up and will sync shortly"
  end

  private

    def set_provider_type
      @provider_type = params[:provider_type]
      @provider_config = DirectBankRegistry.provider_config(@provider_type)

      unless @provider_config
        redirect_to settings_bank_sync_path, alert: "Invalid provider"
      end
    end

    def set_connection
      @connection = Current.family.direct_bank_connections
                           .where(type: connection_class.name)
                           .find(params[:id])
    end

    def connection_class
      # Use the safe registry lookup instead of constantize
      DirectBankRegistry.connection_class(@provider_type) || raise("Invalid provider")
    end

    def create_connection_safely
      # Use explicit method calls based on whitelisted provider types
      case @provider_type.to_s
      when "mercury"
        Current.family.create_mercury_connection!(connection_params)
      when "wise"
        Current.family.create_wise_connection!(connection_params)
      else
        raise ArgumentError, "Unsupported provider type: #{@provider_type}"
      end
    end

    def connection_params
      case @provider_config[:auth_type]
      when :api_key
        { api_key: params[:api_key] }
      when :oauth
        oauth_credentials_from_params
      else
        {}
      end
    end

    def oauth_credentials_from_params
      {
        access_token: params[:access_token],
        refresh_token: params[:refresh_token],
        expires_at: params[:expires_at]
      }
    end

    def render_error(message)
      @connection = connection_class.new
      flash.now[:alert] = message
      render :new, status: :unprocessable_entity
    end

    def format_provider_error(error)
      case error.error_type
      when :authentication_failed
        "Authentication failed. Please check your credentials."
      when :access_forbidden
        "Access forbidden. Please ensure you have the necessary permissions."
      when :rate_limited
        "Rate limit exceeded. Please try again later."
      else
        "Failed to connect: #{error.message}"
      end
    end
end
