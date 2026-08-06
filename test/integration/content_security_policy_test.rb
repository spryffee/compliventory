require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "pages carry an enforcing policy, signed in or not" do
    get login_path
    assert_enforced_policy

    sign_in_as users(:owner)
    get root_path
    assert_enforced_policy
  end

  # The inline importmap is the one script the app cannot avoid, and Turbo reads
  # the meta tag to nonce the style element it builds for the progress bar. All
  # three have to agree or the page loads without its JavaScript.
  test "the importmap script and the meta tag share the request's nonce" do
    sign_in_as users(:owner)
    get root_path

    nonce = response.body[/<meta name="csp-nonce" content="([^"]+)"/, 1]
    assert nonce.present?, "no csp-nonce meta tag"
    assert_includes response.headers["Content-Security-Policy"], "'nonce-#{nonce}'"
    assert_match %r{<script type="importmap"[^>]*nonce="#{Regexp.escape(nonce)}"}, response.body
  end

  private

  def assert_enforced_policy
    policy = response.headers["Content-Security-Policy"]
    assert policy.present?, "no Content-Security-Policy header"
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_includes policy, "object-src 'none'"
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
  end
end
