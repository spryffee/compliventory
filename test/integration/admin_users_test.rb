require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  test "non-admins get the forbidden page" do
    sign_in_as users(:compliance)
    get admin_users_path
    assert_response :forbidden
  end

  test "admins see the user list" do
    sign_in_as users(:admin)
    get admin_users_path
    assert_response :success
    assert_includes response.body, users(:employee).email
  end

  test "role filter narrows the list" do
    sign_in_as users(:admin)
    get admin_users_path(role: "compliance")
    assert_response :success
    assert_includes response.body, users(:compliance).email
    assert_not_includes response.body, users(:employee).email
  end

  test "an admin can change a role, audited" do
    sign_in_as users(:admin)

    assert_difference("AuditEvent.where(event_type: 'user.role_changed').count", 1) do
      patch admin_user_path(users(:employee)), params: { user: { role: "compliance" } }
    end
    assert_redirected_to admin_users_path
    assert users(:employee).reload.compliance?

    event = AuditEvent.where(event_type: "user.role_changed").order(:occurred_at).last
    assert_equal({ "role" => [ "member", "compliance" ] }, event.attribute_changes)
  end

  test "an unchanged role emits no audit event" do
    sign_in_as users(:admin)
    assert_no_difference("AuditEvent.where(event_type: 'user.role_changed').count") do
      patch admin_user_path(users(:employee)), params: { user: { role: "member" } }
    end
  end

  test "unknown roles are rejected" do
    sign_in_as users(:admin)
    patch admin_user_path(users(:employee)), params: { user: { role: "root" } }
    assert_redirected_to admin_users_path
    assert users(:employee).reload.member?
  end
end
