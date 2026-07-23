require "test_helper"

class Assessments::InherentRiskTest < ActiveSupport::TestCase
  # In-memory records keep each rule isolated: no DB writes, no fixture bleed.
  def vendor_with(systems: [], **attrs)
    Vendor.new({ name: "V", owner: users(:owner) }.merge(attrs)).tap { |v| v.systems = systems }
  end

  def system_with(**attrs)
    System.new({ name: "S", owner: users(:owner), status: "active" }.merge(attrs))
  end

  def level(vendor)
    Assessments::InherentRisk.call(vendor)[:level]
  end

  def factors(vendor)
    Assessments::InherentRisk.call(vendor)[:factors]
  end

  test "restricted system data classification scores critical" do
    vendor = vendor_with(systems: [ system_with(data_classification: "restricted") ])
    assert_equal "critical", level(vendor)
    assert_includes factors(vendor), { "factor" => "system_data_classification", "value" => "restricted", "level" => "critical" }
  end

  test "confidential system data classification scores high" do
    assert_equal "high", level(vendor_with(systems: [ system_with(data_classification: "confidential") ]))
  end

  test "a critical system scores critical" do
    assert_equal "critical", level(vendor_with(systems: [ system_with(criticality: "critical") ]))
  end

  test "a high-criticality system scores high" do
    assert_equal "high", level(vendor_with(systems: [ system_with(criticality: "high") ]))
  end

  test "special-category personal data scores high" do
    vendor = vendor_with(systems: [ system_with(personal_data_categories: [ "special_categories" ]) ])
    assert_equal "high", level(vendor)
  end

  test "personal data scores medium — via the vendor flag" do
    assert_equal "medium", level(vendor_with(processes_personal_data: true))
  end

  test "personal data scores medium — via a system that stores it" do
    assert_equal "medium", level(vendor_with(systems: [ system_with(stores_personal_data: true) ]))
  end

  test "data location outside EU/US scores medium" do
    assert_equal "medium", level(vendor_with(data_location: "other"))
  end

  test "an infrastructure vendor scores medium" do
    assert_equal "medium", level(vendor_with(category: "cloud_infra"))
  end

  test "highest level wins and factors are ordered by level desc" do
    vendor = vendor_with(
      category: "cloud_infra",                                   # medium
      processes_personal_data: true,                             # medium
      systems: [ system_with(data_classification: "restricted", criticality: "high") ] # critical + high
    )
    result = Assessments::InherentRisk.call(vendor)

    assert_equal "critical", result[:level]
    assert_equal %w[critical high medium medium], result[:factors].map { |f| f["level"] }
  end

  test "a known-but-benign vendor scores low with no elevating factors" do
    vendor = vendor_with(processes_personal_data: false, data_location: "eu")
    assert_equal "low", level(vendor)
    assert_empty factors(vendor)
  end

  test "a benign system (all risk fields low/false) also scores low" do
    vendor = vendor_with(systems: [ system_with(criticality: "low", data_classification: "internal", stores_personal_data: false) ])
    assert_equal "low", level(vendor)
    assert_empty factors(vendor)
  end

  test "nothing known scores unscored (nil)" do
    result = Assessments::InherentRisk.call(vendor_with)
    assert_nil result[:level]
    assert_empty result[:factors]
  end

  test "retired and pending systems do not count" do
    vendor = vendor_with(systems: [
      system_with(data_classification: "restricted", status: "retired"),
      system_with(criticality: "critical", status: "pending_approval")
    ])
    result = Assessments::InherentRisk.call(vendor)
    assert_nil result[:level], "excluded systems must not contribute risk or count as known"
    assert_empty result[:factors]
  end
end
