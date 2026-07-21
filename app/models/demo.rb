# Public demo mode. When enabled (DEMO_MODE=true, cached in
# config.x.demo_mode at boot), compliventory exposes a persona-picker sign-in
# over shared seed data instead of requiring OIDC, and resets that data nightly
# so the sandbox stays clean. Everything demo-specific hangs off Demo.enabled?.
module Demo
  def self.enabled?
    Rails.configuration.x.demo_mode
  end
end
