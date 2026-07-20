require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email to stripped lowercase" do
    user = User.create!(email: "  Mixed.Case@Example.COM ", name: "Mixed")
    assert_equal "mixed.case@example.com", user.email
  end

  test "email is unique after normalization" do
    User.create!(email: "dup@example.com", name: "First")
    dup = User.new(email: "DUP@example.com", name: "Second")
    assert_not dup.valid?
    assert_includes dup.errors[:email], "has already been taken"
  end

  test "rejects unknown roles" do
    user = User.new(email: "x@example.com", name: "X", role: "superuser")
    assert_not user.valid?
  end

  test "role defaults to member with predicate helpers" do
    user = User.create!(email: "plain@example.com", name: "Plain")
    assert user.member?
    assert_not user.compliance?
    assert_not user.admin?
  end

  test "active scope excludes deactivated users" do
    assert_includes User.active, users(:owner)
    assert_not_includes User.active, users(:inactive)
  end
end
