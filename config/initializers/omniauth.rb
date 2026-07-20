# Single ENV-configured OIDC provider (deliberate divergence from governauthzer's
# multi-IdP DB-backed config — see DESIGN.md). A company has one corporate IdP:
#
#   OIDC_ISSUER        e.g. https://login.example.com/realms/corp
#   OIDC_CLIENT_ID
#   OIDC_CLIENT_SECRET
#
# The strategy is registered unconditionally under the fixed name/path `oidc`;
# the setup lambda reads ENV per request, so configuration changes need only a
# restart, and an unconfigured instance fails the request cleanly instead of at
# boot. The login page hides the SSO button when OIDC_ISSUER is absent.

omniauth_setup = lambda do |env|
  issuer = ENV["OIDC_ISSUER"]
  if issuer.blank?
    # In OmniAuth test mode the mocked callback never talks to an IdP, so a
    # missing ENV config must not fail the request.
    next if OmniAuth.config.test_mode
    raise "oidc_not_configured"
  end

  base_url = Rails.application.routes.default_url_options.then do |o|
    port_suffix = o[:port].nil? ? "" : ":#{o[:port]}"
    "#{o[:protocol]}://#{o[:host]}#{port_suffix}"
  end

  # The strategy builds the discovery URL from client_options.scheme/host/port
  # (not from `issuer`), defaulting to https/nil/443. We MUST parse the issuer
  # URL and propagate scheme/host/port — otherwise an http://localhost:8080
  # issuer triggers HTTPS-to-port-8080 SSL handshake failures.
  issuer_uri = URI.parse(issuer)

  strategy = env["omniauth.strategy"]
  strategy.options[:issuer]    = issuer
  strategy.options[:discovery] = true
  strategy.options[:scope]     = %i[openid email profile]
  strategy.options[:client_options] ||= {}
  strategy.options[:client_options].merge!(
    identifier:   ENV["OIDC_CLIENT_ID"],
    secret:       ENV["OIDC_CLIENT_SECRET"],
    redirect_uri: "#{base_url}/auth/oidc/callback",
    scheme:       issuer_uri.scheme,
    host:         issuer_uri.host,
    port:         issuer_uri.port
  )
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect, name: :oidc, setup: omniauth_setup
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning     = true

# OIDC spec mandates HTTPS for discovery. The `swd` gem hardcodes `URI::HTTPS` as
# the global discovery URL builder. In development we relax this so a local IdP
# on http://localhost:8080 can be discovered. In production the default stays HTTPS.
if Rails.env.development? || Rails.env.test?
  require "swd"
  SWD.url_builder = URI::HTTP
end
