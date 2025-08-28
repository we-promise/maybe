# frozen_string_literal: true

require "omniauth/rails_csrf_protection"

if ENV["OIDC_ISSUER"].present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :openid_connect,
             name: :openid_connect,
             scope: %i[openid email profile],
             response_type: :code,
             issuer: ENV["OIDC_ISSUER"],
             discovery: true,
             pkce: true,
             client_options: {
               identifier: ENV["OIDC_CLIENT_ID"],
               secret: ENV["OIDC_CLIENT_SECRET"],
               redirect_uri: ENV["OIDC_REDIRECT_URI"]
             }
  end
end
