require "test_helper"

class AssetTablesTest < ActionDispatch::IntegrationTest
  test "sorting and filtering via query params" do
    sign_in_as users(:employee)

    get vendors_path(sort: "name", dir: "desc")
    assert_response :success
    assert response.body.index("NewTool.io") < response.body.index("Acme Cloud")

    get vendors_path(status: "active")
    assert_response :success
    assert_includes response.body, "Acme Cloud"
    assert_not_includes response.body, "NewTool.io"

    get vendors_path(q: "newtool")
    assert_response :success
    assert_includes response.body, "NewTool.io"
    assert_not_includes response.body, "Acme Cloud"
  end

  test "garbage sort params still render" do
    sign_in_as users(:employee)
    get vendors_path(sort: "evil", dir: "nope")
    assert_response :success
  end

  test "a filtered empty result offers to clear filters" do
    sign_in_as users(:employee)
    get systems_path(q: "zzz-no-match")
    assert_response :success
    assert_includes response.body, "clear filters"
  end

  test "column selection persists to ui_preferences and drives rendering" do
    user = users(:employee)
    sign_in_as user

    patch table_preference_path("vendors"), params: { columns: %w[data_location bogus] }
    assert_response :redirect
    assert_equal %w[data_location], user.reload.ui_preferences["vendors_table_columns"]

    get vendors_path
    assert_response :success
    # Header sort links exist only for visible columns.
    assert_includes response.body, "sort=data_location"
    assert_not_includes response.body, "sort=risk_tier"
  end

  test "full screen mode is a cookie, so it survives navigation" do
    sign_in_as users(:employee)

    patch table_view_path, params: { expanded: "1", return_to: "/vendors?status=active" }
    assert_redirected_to "/vendors?status=active"
    assert_equal "expanded", cookies[:table_view]

    get vendors_path
    assert_response :success
    assert_includes response.body, "table-expanded"
    assert_includes response.body, "Exit full screen"

    patch table_view_path, params: { expanded: "0", return_to: "/vendors" }
    get vendors_path
    assert_response :success
    assert_not_includes response.body, "table-expanded"
  end

  test "full screen fits more rows on a page" do
    26.times { |i| Vendor.create!(name: "Bulk #{i}", owner: users(:owner), status: "active") }
    sign_in_as users(:employee)

    get vendors_path
    assert_includes response.body, "Page 1 of 2"

    cookies[:table_view] = "expanded"
    get vendors_path
    assert_not_includes response.body, "Page 1 of"
  end

  test "the full screen toggle refuses to redirect off-site" do
    sign_in_as users(:employee)
    patch table_view_path, params: { expanded: "1", return_to: "//evil.example/vendors" }
    assert_redirected_to root_path
  end

  test "unknown table key is a bad request" do
    sign_in_as users(:employee)
    patch table_preference_path("nonsense"), params: { columns: %w[name] }
    assert_response :bad_request
  end

  test "table preferences require sign-in" do
    patch table_preference_path("vendors"), params: { columns: %w[name] }
    assert_redirected_to login_path
  end
end
