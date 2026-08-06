require "test_helper"

# The production boot check (config/initializers/config_check.rb). The initializer
# only raises in production; the rules themselves are checked here.
class ConfigCheckTest < ActiveSupport::TestCase
  CONFIGURED = {
    "COMPLIVENTORY_HOST" => "https://compliventory.example.com",
    "OIDC_ISSUER" => "https://login.example.com/realms/corp",
    "OIDC_CLIENT_ID" => "compliventory",
    "OIDC_CLIENT_SECRET" => "s3cret"
  }.freeze

  test "a configured environment has nothing to report" do
    assert_empty Compliventory.config_problems(CONFIGURED)
  end

  test "an unset host is reported" do
    problems = Compliventory.config_problems(CONFIGURED.merge("COMPLIVENTORY_HOST" => nil))
    assert_equal 1, problems.size
    assert_match "COMPLIVENTORY_HOST is not set", problems.sole
  end

  # host.rb treats a bare hostname as the host and defaults the scheme to http,
  # so this fails silently rather than loudly without the check.
  test "a host without a scheme is reported" do
    problems = Compliventory.config_problems(CONFIGURED.merge("COMPLIVENTORY_HOST" => "compliventory.example.com"))
    assert_match "not an absolute URL", problems.sole
  end

  test "every missing OIDC variable is reported at once, not one per deploy" do
    problems = Compliventory.config_problems(CONFIGURED.merge(
      "OIDC_ISSUER" => nil, "OIDC_CLIENT_ID" => "", "OIDC_CLIENT_SECRET" => nil
    ))
    assert_equal 3, problems.size
  end

  test "demo mode needs no OIDC client — the persona picker replaces it" do
    demo = { "COMPLIVENTORY_HOST" => "https://demo.example.com", "DEMO_MODE" => "true" }
    assert_empty Compliventory.config_problems(demo)
  end
end
