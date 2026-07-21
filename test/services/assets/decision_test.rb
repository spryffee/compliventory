require "test_helper"

module Assets
  class DecisionTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      Current.correlation_id = SecureRandom.uuid
    end

    teardown do
      Current.reset
    end

    test "approve activates a pending asset, audits, notifies the owner" do
      result = nil
      assert_enqueued_emails 1 do
        result = Approver.call(asset: vendors(:pending_vendor), actor: users(:compliance), comment: "ok")
      end
      assert result.success
      assert_equal "active", vendors(:pending_vendor).reload.status

      event = AuditEvent.where(event_type: "vendor.approved").sole
      assert_equal({ "status" => [ "pending_approval", "active" ] }, event.attribute_changes)
      assert_equal "ok", event.justification
    end

    test "reject destroys the row with a snapshot in the audit event" do
      vendor = vendors(:pending_vendor)
      result = nil
      assert_enqueued_emails 1 do
        assert_difference("Vendor.count", -1) do
          result = Rejecter.call(asset: vendor, actor: users(:compliance), comment: "duplicate")
        end
      end
      assert result.success

      event = AuditEvent.where(event_type: "vendor.rejected").sole
      assert_equal "NewTool.io", event.metadata["snapshot"]["name"]
      assert_equal vendor.id, event.target_id("Vendor")
      assert_equal "duplicate", event.justification
    end

    test "rejecting a pending asset destroys its proposals too" do
      ChangeProposal.create!(
        asset: vendors(:pending_vendor), proposer: users(:employee), lane: "owner",
        attribute_changes: { "description" => [ nil, "x" ] }
      )
      assert_difference("ChangeProposal.count", -1) do
        Rejecter.call(asset: vendors(:pending_vendor), actor: users(:compliance))
      end
    end

    test "only compliance decides, and only pending assets" do
      assert_equal :not_permitted, Approver.call(asset: vendors(:pending_vendor), actor: users(:admin)).code
      assert_equal :not_permitted, Rejecter.call(asset: vendors(:pending_vendor), actor: users(:owner)).code
      assert_equal :not_pending, Approver.call(asset: vendors(:acme), actor: users(:compliance)).code
      assert_equal :not_pending, Rejecter.call(asset: vendors(:acme), actor: users(:compliance)).code
    end
  end
end
