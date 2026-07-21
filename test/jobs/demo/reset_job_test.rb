require "test_helper"

class Demo::ResetJobTest < ActiveJob::TestCase
  test "is a no-op unless demo mode is on" do
    before = Vendor.count
    Vendor.create!(name: "Left Alone", owner: users(:owner))

    Demo::ResetJob.perform_now

    assert_equal before + 1, Vendor.count
    assert Vendor.exists?(name: "Left Alone")
  end

  test "wipes and reseeds the sandbox when demo mode is on" do
    Vendor.create!(name: "Doomed", owner: users(:owner))

    with_demo_mode { Demo::ResetJob.perform_now }

    assert_not Vendor.exists?(name: "Doomed")
    assert_equal 10, Vendor.count
  end
end
