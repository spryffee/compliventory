require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Selenium Manager looks for `google-chrome`; distributions that ship only
  # `chromium` have to be pointed at it.
  BROWSER = ENV["CHROME_BINARY"].presence ||
            %w[/usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser].find { |path| File.executable?(path) }

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ] do |options|
    options.binary = BROWSER if BROWSER
    options.add_argument("--no-sandbox")
  end

  setup { OmniAuth.config.test_mode = true }

  teardown do
    OmniAuth.config.mock_auth[:oidc] = nil
    OmniAuth.config.test_mode = false
  end

  # Through the real OIDC callback, as the integration tests do — /dev/sign-in
  # exists only in development. Signing in again simply replaces the session, so
  # a test can change actor mid-flow without a logout step.
  def sign_in_as(user)
    OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(
      provider: "oidc", uid: "test-sub-#{user.id}", info: { email: user.email }
    )
    visit "/auth/oidc/callback"
  end
end
