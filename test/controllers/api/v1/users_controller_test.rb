require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  RAW_TOKEN = "cvt_test-sync-token-000000000000000000000000000".freeze

  def auth_headers
    { "Authorization" => "Bearer #{RAW_TOKEN}" }
  end

  # --- authentication --------------------------------------------------------

  test "rejects requests without a token" do
    get "/api/v1/users"
    assert_response :unauthorized
    assert_response_schema_confirm(401)
    assert_equal "unauthorized", JSON.parse(response.body).dig("error", "code")
  end

  test "rejects an expired token" do
    get "/api/v1/users", headers: { "Authorization" => "Bearer cvt_test-expired-token-0000000000000000000000000" }
    assert_response :unauthorized
  end

  test "rejects a syntactically valid but unknown token" do
    get "/api/v1/users", headers: { "Authorization" => "Bearer #{ApiToken.generate_raw_token}" }
    assert_response :unauthorized
  end

  # --- GET /users ------------------------------------------------------------

  test "lists all users ordered by email" do
    get "/api/v1/users", headers: auth_headers
    assert_response :success
    assert_response_schema_confirm(200)

    body = JSON.parse(response.body)
    assert_equal User.count, body.size
    assert_equal body.map { |u| u["email"] }.sort, body.map { |u| u["email"] }
  end

  # --- POST /users (upsert) --------------------------------------------------

  test "creates an unknown email with 201 and audits user.synced" do
    assert_difference([ "User.count", "AuditEvent.where(event_type: 'user.synced').count" ], 1) do
      post "/api/v1/users", params: { email: "new.hire@example.com", name: "New Hire" },
                            headers: auth_headers, as: :json
    end
    assert_response :created
    assert_response_schema_confirm(201)

    body = JSON.parse(response.body)
    assert_equal "new.hire@example.com", body["email"]
    assert_equal "member", body["role"]
    assert body["active"]

    event = AuditEvent.where(event_type: "user.synced").order(:occurred_at).last
    assert_equal "system", event.actor_type
    assert_equal api_tokens(:sync).id, event.metadata["api_token_id"]
  end

  test "updates an existing email with 200" do
    assert_no_difference("User.count") do
      post "/api/v1/users", params: { email: users(:employee).email, name: "Eve Renamed" },
                            headers: auth_headers, as: :json
    end
    assert_response :success
    assert_response_schema_confirm(200)
    assert_equal "Eve Renamed", users(:employee).reload.name
  end

  test "deactivates via active: false" do
    post "/api/v1/users", params: { email: users(:employee).email, name: users(:employee).name, active: false },
                          headers: auth_headers, as: :json
    assert_response :success
    assert_not users(:employee).reload.active?
  end

  test "an unchanged payload is a no-op without audit" do
    user = users(:employee)
    assert_no_difference("AuditEvent.count") do
      post "/api/v1/users", params: { email: user.email, name: user.name, active: true },
                            headers: auth_headers, as: :json
    end
    assert_response :success
  end

  test "upsert matches email case-insensitively" do
    assert_no_difference("User.count") do
      post "/api/v1/users", params: { email: users(:employee).email.upcase, name: "Eve Employee" },
                            headers: auth_headers, as: :json
    end
    assert_response :success
  end

  test "missing name yields the parameter_missing envelope" do
    post "/api/v1/users", params: { email: "x@example.com" }, headers: auth_headers, as: :json
    assert_response :bad_request
    assert_response_schema_confirm(400)
    assert_equal "parameter_missing", JSON.parse(response.body).dig("error", "code")
  end

  test "blank name is treated as missing" do
    post "/api/v1/users", params: { email: "x@example.com", name: "" }, headers: auth_headers, as: :json
    assert_response :bad_request
  end

  test "role is not settable via sync" do
    post "/api/v1/users", params: { email: "sneaky@example.com", name: "Sneaky", role: "admin" },
                          headers: auth_headers, as: :json
    assert_response :created
    assert_equal "member", User.find_by(email: "sneaky@example.com").role
  end
end
