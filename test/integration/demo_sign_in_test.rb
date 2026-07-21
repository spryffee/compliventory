require "test_helper"

class DemoSignInTest < ActionDispatch::IntegrationTest
  test "demo routes 404 when demo mode is off" do
    get demo_sign_in_path
    assert_response :not_found

    post demo_sign_in_path, params: { email: users(:employee).email }
    assert_response :not_found
  end

  test "the persona picker lists active users in demo mode" do
    with_demo_mode do
      get demo_sign_in_path
      assert_response :success
      assert_includes response.body, "Try compliventory"
      assert_includes response.body, "Alice Admin"
      assert_includes response.body, "resets every night"
      assert_not_includes response.body, "Gary Gone"   # inactive
    end
  end

  test "picking a persona signs the visitor in" do
    with_demo_mode do
      post demo_sign_in_path, params: { email: users(:employee).email }
      assert_redirected_to root_path
      follow_redirect!
      assert_includes response.body, "Welcome, Eve"
      assert_includes response.body, "Demo sandbox"   # banner
    end
  end

  test "an unknown or inactive persona is rejected" do
    with_demo_mode do
      post demo_sign_in_path, params: { email: "nobody@example.com" }
      assert_redirected_to demo_sign_in_path

      post demo_sign_in_path, params: { email: users(:inactive).email }
      assert_redirected_to demo_sign_in_path
    end
  end

  test "login redirects to the persona picker in demo mode" do
    with_demo_mode do
      get login_path
      assert_redirected_to demo_sign_in_path
    end
  end

  test "the demo sign-in emits an audit event" do
    with_demo_mode do
      assert_difference -> { AuditEvent.where(event_type: "auth.demo_login").count }, 1 do
        post demo_sign_in_path, params: { email: users(:employee).email }
      end
    end
  end

  test "no demo banner outside demo mode" do
    sign_in_as users(:owner)
    get root_path
    assert_response :success
    assert_not_includes response.body, "Demo sandbox"
  end
end
