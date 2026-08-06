# One policy for every environment — a CSP that only holds in production is a
# CSP nobody notices breaking.
#
# Nonces rather than 'unsafe-inline': importmap emits an inline <script> with the
# importmap JSON, and Turbo builds its progress-bar <style> element at runtime,
# reading the nonce from the csp_meta_tag in the layout. Both are nonced for us,
# so no view has to think about it.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    # Google Fonts serves the stylesheet from one host and the files from another.
    policy.style_src   :self, "https://fonts.googleapis.com"
    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    policy.img_src     :self, :data
    policy.connect_src :self
    policy.object_src  :none
    policy.base_uri    :self
    policy.form_action :self
    # Nothing here is meant to be embedded; this is the header that actually
    # stops clickjacking, X-Frame-Options being the older half-measure.
    policy.frame_ancestors :none
  end

  # Per request, not per session: the app keeps no server-side session (auth is a
  # signed cookie), so a session-derived nonce would be the empty string here.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
