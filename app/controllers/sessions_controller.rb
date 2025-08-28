class SessionsController < ApplicationController
  before_action :set_session, only: :destroy
  skip_authentication only: %i[new create openid_connect failure]

  layout "auth"

  def new
  end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      if user.otp_required?
        session[:mfa_user_id] = user.id
        redirect_to verify_mfa_path
      else
        @session = create_session_for(user)
        redirect_to root_path
      end
    else
      flash.now[:alert] = t(".invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @session.destroy
    redirect_to new_session_path, notice: t(".logout_successful")
  end

  def openid_connect
    auth = request.env["omniauth.auth"]
    if auth && (user = User.find_by(email: auth.info.email))
      @session = create_session_for(user)
      redirect_to root_path
    else
      redirect_to new_session_path, alert: t(".failed")
    end
  end

  def failure
    redirect_to new_session_path, alert: t(".failed")
  end

  private
    def set_session
      @session = Current.user.sessions.find(params[:id])
    end
end
