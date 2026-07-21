require "test_helper"

class AssetTableTest < ActiveSupport::TestCase
  def table(user: users(:employee), **params)
    VendorTable.new(user: user, params: ActionController::Parameters.new(params))
  end

  test "defaults: sort by name asc, default columns" do
    t = table
    assert_equal "name", t.sort_key
    assert_equal "asc", t.sort_dir
    assert_equal %w[name category status risk_tier owner], t.visible_columns.map(&:key)
    assert_not t.filtered?
  end

  test "sort and dir outside the allowlist fall back" do
    t = table(sort: "created_at; DROP TABLE vendors", dir: "sideways")
    assert_equal "name", t.sort_key
    assert_equal "asc", t.sort_dir
  end

  test "sorts by a column descending" do
    names = table(sort: "name", dir: "desc").scope.map(&:name)
    assert_equal names.sort.reverse, names
  end

  test "sorts by the joined owner name" do
    t = table(sort: "owner", dir: "asc")
    owners = t.scope.map { |v| v.owner.name }
    assert_equal owners.sort, owners
  end

  test "filters by status" do
    t = table(status: "pending_approval")
    assert t.filtered?
    assert_equal [ vendors(:pending_vendor) ], t.scope.to_a
  end

  test "searches name and description case-insensitively" do
    assert_includes table(q: "acme").scope, vendors(:acme)
    assert_includes table(q: "object storage").scope, vendors(:acme)
    assert_empty table(q: "no such vendor").scope
  end

  test "visible columns come from ui_preferences, stale keys drop, name is forced" do
    user = users(:employee)
    user.update!(ui_preferences: { "vendors_table_columns" => %w[risk_tier data_location gone_column] })
    assert_equal %w[name risk_tier data_location], table(user: user).visible_columns.map(&:key)
  end

  test "empty preference falls back to defaults" do
    user = users(:employee)
    user.update!(ui_preferences: { "vendors_table_columns" => [] })
    assert_equal %w[name category status risk_tier owner], table(user: user).visible_columns.map(&:key)
  end

  test "system table sorts by the joined vendor name, vendorless systems last" do
    t = SystemTable.new(user: users(:employee), params: ActionController::Parameters.new(sort: "vendor", dir: "asc"))
    assert_equal System.count, t.scope.length
    assert_equal "Issue Tracker", t.scope.first.name
    assert_nil t.scope.to_a.last.vendor
  end
end
