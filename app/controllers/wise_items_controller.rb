class WiseItemsController < ApplicationController
  before_action :set_wise_item, only: [ :show, :destroy, :sync, :setup_accounts, :complete_account_setup ]

  def index
    @wise_items = Current.family.wise_items.active.ordered
    render layout: "settings"
  end

  def show
  end

  def new
    @wise_item = Current.family.wise_items.build
  end

  def create
    api_key = wise_params[:api_key]

    return render_error("Please enter a Wise API key.") if api_key.blank?

    begin
      @wise_item = Current.family.create_wise_item!(
        api_key: api_key,
        item_name: "Wise Connection"
      )

      redirect_to wise_items_path, notice: "Wise connection added successfully! Your accounts will appear shortly as they sync in the background."
    rescue ArgumentError => e
      render_error(e.message, api_key)
    rescue Provider::Wise::WiseError => e
      error_message = case e.error_type
      when :authentication_failed
        "Invalid API key. Please check that you copied the complete API key from Wise."
      when :access_forbidden
        "Access forbidden. Please ensure your API key has the necessary permissions."
      else
        "Failed to connect: #{e.message}"
      end
      render_error(error_message, api_key)
    rescue => e
      Rails.logger.error("Wise connection error: #{e.message}")
      render_error("An unexpected error occurred. Please try again or contact support.", api_key)
    end
  end

  def destroy
    @wise_item.destroy_later
    redirect_to wise_items_path, notice: "Wise connection will be removed"
  end

  def sync
    @wise_item.sync_later
    redirect_to wise_item_path(@wise_item), notice: "Sync started"
  end

  def setup_accounts
    @wise_accounts = @wise_item.wise_accounts.includes(:account).where(accounts: { id: nil })
    @account_type_options = [
      [ "Checking or Savings Account", "Depository" ],
      [ "Skip - don't add", "Skip" ]
    ]

    # Subtype options for each account type
    @subtype_options = {
      "Depository" => {
        label: "Account Subtype:",
        options: Depository::SUBTYPES.map { |k, v| [ v[:long], k ] }
      }
    }
  end

  def complete_account_setup
    account_types = params[:account_types] || {}
    account_subtypes = params[:account_subtypes] || {}

    account_types.each do |wise_account_id, selected_type|
      # Skip accounts that the user chose not to add
      next if selected_type == "Skip"

      wise_account = @wise_item.wise_accounts.find(wise_account_id)

      # Skip if account already exists
      next if wise_account.account.present?

      # Create account based on type
      subtype = account_subtypes[wise_account_id] || "checking"

      # Use the custom Wise account creation that handles opening balance properly
      account = Account.create_from_wise_account(
        wise_account,
        selected_type,
        subtype
      )

      unless account.persisted?
        Rails.logger.error("Failed to create account for Wise account #{wise_account_id}: #{account.errors.full_messages.join(', ')}")
      end
    end

    # Clear the pending setup flag
    @wise_item.update!(pending_account_setup: false)

    redirect_to wise_items_path, notice: "Accounts have been set up successfully!"
  end

  private

    def set_wise_item
      @wise_item = Current.family.wise_items.find(params[:id])
    end

    def wise_params
      params.require(:wise_item).permit(:api_key)
    end

    def render_error(message, api_key = nil)
      @wise_item = Current.family.wise_items.build(api_key: api_key)
      flash.now[:alert] = message
      render :new, status: :unprocessable_entity
    end
end
