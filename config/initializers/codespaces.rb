# Dev-only adjustments for GitHub Codespaces
if Rails.env.development? && ENV["CODESPACES"] == "true"
  # Example: forwarded URLs like https://<repo>-<user>-<port>.app.github.dev
  forwarding_domain = ENV["GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"] # typically "app.github.dev"

  # Append allowed hosts ONLY if Host Authorization is enabled (config.hosts is an Array).
  # If it's nil, Host Authorization is disabled and we leave it alone.
  if Rails.application.config.hosts.is_a?(Array)
    if forwarding_domain.present?
      Rails.application.config.hosts << /\A.*\.#{Regexp.escape(forwarding_domain)}\z/
    end
    # Older/alternative preview domain
    Rails.application.config.hosts << /\A.*\.githubpreview\.dev\z/
  end

  # If you use the VS Code "Preview" (iframe), you need SameSite=None; Secure
  # Codespaces serves over HTTPS, so secure: true is OK here.
  Rails.application.config.session_store :cookie_store,
    key: "_app_session",
    same_site: :none,
    secure: true

  # Behind the proxy, Origin can differ; relax the origin check instead of disabling CSRF entirely.
  Rails.application.config.action_controller.forgery_protection_origin_check = false
end
