require "test_helper"

module Assets
  class EditorTest < ActiveSupport::TestCase
    setup do
      Current.correlation_id = SecureRandom.uuid
    end

    teardown do
      Current.reset
    end

    test "owner edit of regular fields applies and audits" do
      result = nil
      assert_difference("AuditEvent.where(event_type: 'vendor.updated').count", 1) do
        result = Editor.call(asset: vendors(:acme), actor: users(:owner),
                             attributes: { description: "New description", notes: "Renewed 2026" })
      end
      assert result.success
      assert_equal "New description", vendors(:acme).reload.description

      event = AuditEvent.where(event_type: "vendor.updated").recent_first.first
      assert_equal users(:owner).id, event.actor_id
      assert_equal [ "Object storage and CDN.", "New description" ], event.attribute_changes["description"]
      assert_equal vendors(:acme).id, event.target_id("Vendor")
    end

    test "owner touching a compliance field fails whole edit, nothing applied" do
      result = nil
      assert_no_difference("AuditEvent.count") do
        result = Editor.call(asset: vendors(:acme), actor: users(:owner),
                             attributes: { description: "sneaky", risk_tier: "low" })
      end
      assert_not result.success
      assert_equal :not_permitted, result.code
      assert_includes result.context[:fields], "risk_tier"
      assert_equal "Object storage and CDN.", vendors(:acme).reload.description
    end

    test "compliance edits compliance fields directly" do
      result = Editor.call(asset: systems(:tracker), actor: users(:compliance),
                           attributes: { criticality: "critical" })
      assert result.success
      assert_equal "critical", systems(:tracker).reload.criticality
      assert_equal 1, AuditEvent.where(event_type: "system.updated").count
    end

    test "unrelated member cannot edit anything" do
      result = Editor.call(asset: vendors(:acme), actor: users(:employee),
                           attributes: { name: "Evil Corp" })
      assert_not result.success
      assert_equal :not_permitted, result.code
      assert_equal "Acme Cloud", vendors(:acme).reload.name
    end

    test "no-op diff emits no audit event" do
      assert_no_difference("AuditEvent.count") do
        result = Editor.call(asset: vendors(:acme), actor: users(:owner),
                             attributes: { name: "Acme Cloud" })
        assert result.success
      end
    end

    test "validation failure returns the record with errors" do
      result = Editor.call(asset: vendors(:acme), actor: users(:owner),
                           attributes: { name: "" })
      assert_not result.success
      assert_equal :validation_failed, result.code
      assert result.context[:record].errors[:name].any?
    end
  end
end
