class Settings::LunchFlowController < ApplicationController
  layout "settings"

  def show
    @breadcrumbs = [
      [ "Home", root_path ],
      [ "Bank Sync", settings_bank_sync_path ],
      [ "Lunch Flow", nil ]
    ]
  end
end
