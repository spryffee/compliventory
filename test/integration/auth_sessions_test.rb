require "test_helper"

class AuthSessionsTest < ActionDispatch::IntegrationTest
  test "signed-out visitors are redirected to login" do
    get root_path
    assert_redirected_to login_path
  end

  test "the login page renders signed out" do
    get login_path
    assert_response :success
  end

  test "a signed-in user sees the dashboard" do
    sign_in_as users(:employee)
    get root_path
    assert_response :success
    assert_includes response.body, "Eve"
  end

  test "sign out clears the session" do
    sign_in_as users(:employee)
    delete logout_path
    assert_redirected_to login_path

    get root_path
    assert_redirected_to login_path
  end

  test "a user deactivated mid-session is signed out on the next request" do
    sign_in_as users(:employee)
    users(:employee).update!(active: false)

    get root_path
    assert_redirected_to login_path
  end

  test "dev sign-in routes do not exist outside development" do
    get "/dev/sign-in"
    assert_response :not_found
  end
end
