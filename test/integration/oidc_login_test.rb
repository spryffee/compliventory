require "test_helper"

# Exercises OmniauthSessionsController#callback through the real OmniAuth
# middleware stack using test mode. The callback's job is email matching against
# the trusted corporate IdP: active user with that email → sign in; unknown or
# inactive → the "ask your admin to sync you" page; never JIT-create.
class OidcLoginTest < ActionDispatch::IntegrationTest
  def setup
    OmniAuth.config.test_mode = true
  end

  def teardown
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:oidc] = nil
  end

  def mock_oidc(email:)
    OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(
      provider: "oidc", uid: "some-subject", info: { email: email }
    )
  end

  test "a known active email signs in and emits an audit event" do
    mock_oidc(email: users(:employee).email)

    assert_difference("AuditEvent.where(event_type: 'auth.login').count", 1) do
      get "/auth/oidc/callback"
    end
    assert_redirected_to root_path
    assert cookies[:session].present?, "a session cookie is set"
  end

  test "email matching is case-insensitive" do
    mock_oidc(email: users(:employee).email.upcase)

    get "/auth/oidc/callback"
    assert_redirected_to root_path
  end

  test "an unknown email renders the unregistered page without signing in" do
    mock_oidc(email: "stranger@example.com")

    assert_no_difference("AuditEvent.count") do
      get "/auth/oidc/callback"
    end
    assert_response :forbidden
    assert_includes response.body, "stranger@example.com"
    assert cookies[:session].blank?, "no session is established"
  end

  test "an inactive user is refused" do
    mock_oidc(email: users(:inactive).email)

    get "/auth/oidc/callback"
    assert_response :forbidden
    assert cookies[:session].blank?
  end

  test "a missing email claim redirects to login with an alert" do
    OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(provider: "oidc", uid: "no-email")

    get "/auth/oidc/callback"
    assert_redirected_to login_path
  end

  test "the failure endpoint redirects to login" do
    get "/auth/failure", params: { message: "invalid_credentials" }
    assert_redirected_to login_path
  end
end
