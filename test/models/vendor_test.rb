require "test_helper"

class VendorTest < ActiveSupport::TestCase
  test "valid fixture" do
    assert vendors(:acme).valid?
  end

  test "requires a unique name" do
    vendor = Vendor.new(name: "Acme Cloud", owner: users(:owner))
    assert_not vendor.valid?
    assert vendor.errors[:name].any?
  end

  test "rejects unknown enum-ish values" do
    vendor = vendors(:acme)
    vendor.assign_attributes(category: "hosting", status: "gone", data_location: "moon", risk_tier: "extreme")
    assert_not vendor.valid?
    assert_equal %i[category data_location risk_tier status], vendor.errors.attribute_names.sort
  end

  test "rejects malformed website and contact_email" do
    vendor = vendors(:acme)
    vendor.assign_attributes(website: "acme.example", contact_email: "not-an-email")
    assert_not vendor.valid?
    assert vendor.errors[:website].any?
    assert vendor.errors[:contact_email].any?
  end

  # The four review scopes now agree on who is in the queue at all.
  test "an archived vendor is on no review queue, however good its dates" do
    archived = Vendor.create!(name: "Gone Co", owner: users(:owner), status: "archived",
                              last_assessed_on: Date.current, next_review_on: Date.current + 1.year)

    assert_not_includes Vendor.review_up_to_date, archived
  end

  test "owned_or_delegated_to? covers owner and delegate, not others" do
    vendor = vendors(:acme)
    assert vendor.owned_or_delegated_to?(users(:owner))
    assert vendor.owned_or_delegated_to?(users(:delegate))
    assert_not vendor.owned_or_delegated_to?(users(:employee))
  end
end
