require "test_helper"

class DelegationTest < ActiveSupport::TestCase
  test "one delegation per user per asset" do
    duplicate = Delegation.new(asset: vendors(:acme), user: users(:delegate))
    assert_not duplicate.valid?
    assert duplicate.errors[:user_id].any?
  end

  test "same user may be delegate on different assets" do
    assert Delegation.new(asset: vendors(:pending_vendor), user: users(:delegate)).valid?
  end
end
