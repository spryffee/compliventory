require "test_helper"

module Assets
  class SubmitterTest < ActiveSupport::TestCase
    setup do
      Current.correlation_id = SecureRandom.uuid
    end

    teardown do
      Current.reset
    end

    test "member submission creates a pending vendor and audits" do
      result = nil
      assert_difference("AuditEvent.where(event_type: 'vendor.submitted').count", 1) do
        result = Submitter.call(asset_class: Vendor, actor: users(:employee),
                                attributes: { name: "FreshSaaS", category: "saas", owner_id: users(:employee).id })
      end
      assert result.success
      vendor = result.value
      assert_equal "pending_approval", vendor.status

      event = AuditEvent.where(event_type: "vendor.submitted").recent_first.first
      assert_equal "pending_approval", event.metadata["status"]
      assert_equal vendor.id, event.target_id("Vendor")
    end

    test "compliance submission is self-approved and starts active" do
      result = Submitter.call(asset_class: System, actor: users(:compliance),
                              attributes: { name: "HR Portal", owner_id: users(:owner).id })
      assert result.success
      assert_equal "active", result.value.status
    end

    test "risk_tier is stripped from non-compliance submissions" do
      result = Submitter.call(asset_class: Vendor, actor: users(:employee),
                              attributes: { name: "Sneaky Inc", owner_id: users(:employee).id, risk_tier: "low" })
      assert result.success
      assert_nil result.value.risk_tier
    end

    test "compliance may set risk_tier at submission" do
      result = Submitter.call(asset_class: Vendor, actor: users(:compliance),
                              attributes: { name: "Assessed Inc", owner_id: users(:owner).id, risk_tier: "high" })
      assert result.success
      assert_equal "high", result.value.risk_tier
    end

    test "validation failure creates nothing" do
      result = nil
      assert_no_difference([ "Vendor.count", "AuditEvent.count" ]) do
        result = Submitter.call(asset_class: Vendor, actor: users(:employee),
                                attributes: { name: "Acme Cloud", owner_id: users(:employee).id })
      end
      assert_not result.success
      assert_equal :validation_failed, result.code
    end
  end
end
