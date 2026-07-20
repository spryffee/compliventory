require "test_helper"

class AdminApiTokensTest < ActionDispatch::IntegrationTest
  test "non-admins are forbidden" do
    sign_in_as users(:employee)
    get admin_api_tokens_path
    assert_response :forbidden
  end

  test "creating a token shows the plain value exactly once" do
    sign_in_as users(:admin)

    assert_difference("ApiToken.count", 1) do
      post admin_api_tokens_path, params: { api_token: { name: "CI runner" } }
    end
    follow_redirect!
    assert_match(/cvt_[A-Za-z0-9_-]+/, response.body, "plain token shown after creation")

    get admin_api_tokens_path
    assert_no_match(/cvt_[A-Za-z0-9_-]{40,}/, response.body, "plain token not shown again")
  end

  test "creation is audited" do
    sign_in_as users(:admin)
    assert_difference("AuditEvent.where(event_type: 'api_token.created').count", 1) do
      post admin_api_tokens_path, params: { api_token: { name: "Bridge" } }
    end
  end

  test "revoking destroys the row and audits a snapshot" do
    sign_in_as users(:admin)
    token = api_tokens(:sync)

    assert_difference("ApiToken.count", -1) do
      delete admin_api_token_path(token)
    end
    event = AuditEvent.where(event_type: "api_token.deleted").order(:occurred_at).last
    assert_equal "HRIS sync", event.metadata.dig("snapshot", "name")
  end

  test "a blank name re-renders the form" do
    sign_in_as users(:admin)
    assert_no_difference("ApiToken.count") do
      post admin_api_tokens_path, params: { api_token: { name: "" } }
    end
    assert_response :unprocessable_content
  end
end
