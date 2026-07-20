require "test_helper"

class SystemTest < ActiveSupport::TestCase
  test "valid fixtures, with and without vendor" do
    assert systems(:tracker).valid?
    assert systems(:wiki).valid?
    assert_nil systems(:wiki).vendor
  end

  test "rejects unknown personal data categories" do
    system = systems(:tracker)
    system.personal_data_categories = %w[employees aliens]
    assert_not system.valid?
    assert_match "aliens", system.errors[:personal_data_categories].first
  end

  test "personal_data_categories drops blank checkbox sentinel" do
    system = systems(:tracker)
    system.personal_data_categories = [ "", "employees" ]
    assert_equal %w[employees], system.personal_data_categories
  end

  test "rejects unknown enum-ish values" do
    system = systems(:tracker)
    system.assign_attributes(status: "gone", criticality: "extreme", data_classification: "secret", authentication_method: "carrier_pigeon")
    assert_not system.valid?
    assert_equal %i[authentication_method criticality data_classification status], system.errors.attribute_names.sort
  end
end
