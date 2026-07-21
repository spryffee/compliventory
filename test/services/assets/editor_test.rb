require "test_helper"

module Assets
  class EditorTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

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
      assert_equal %w[description notes], result.value.applied_changes.keys.sort
      assert_empty result.value.proposals
      assert_equal "New description", vendors(:acme).reload.description

      event = AuditEvent.where(event_type: "vendor.updated").recent_first.first
      assert_equal users(:owner).id, event.actor_id
      assert_equal [ "Object storage and CDN.", "New description" ], event.attribute_changes["description"]
      assert_equal vendors(:acme).id, event.target_id("Vendor")
    end

    test "compliance edits everything directly, no proposals" do
      result = Editor.call(asset: systems(:tracker), actor: users(:compliance),
                           attributes: { criticality: "critical", description: "x" })
      assert result.success
      assert_empty result.value.proposals
      assert_equal "critical", systems(:tracker).reload.criticality
      assert_equal 1, AuditEvent.where(event_type: "system.updated").count
    end

    test "owner ⚖ edit splits: regular applied, compliance-lane proposal created" do
      result = nil
      assert_difference("ChangeProposal.compliance_lane.count", 1) do
        result = Editor.call(asset: vendors(:acme), actor: users(:owner),
                             attributes: { notes: "note", processes_personal_data: false },
                             justification: "cleanup")
      end
      assert result.success
      assert_equal %w[notes], result.value.applied_changes.keys

      acme = vendors(:acme).reload
      assert_equal "note", acme.notes
      assert_equal true, acme.processes_personal_data # untouched — proposed only

      proposal = result.value.proposals.sole
      assert_equal "compliance", proposal.lane
      assert_equal({ "processes_personal_data" => [ true, false ] }, proposal.attribute_changes)
      assert_equal "cleanup", proposal.justification
      assert_equal 1, AuditEvent.where(event_type: "proposal.created").count
    end

    test "non-owner regular edit becomes an owner-lane proposal, nothing applied" do
      result = Editor.call(asset: vendors(:acme), actor: users(:employee),
                           attributes: { description: "suggestion" })
      assert result.success
      assert_empty result.value.applied_changes
      assert_equal "Object storage and CDN.", vendors(:acme).reload.description

      proposal = result.value.proposals.sole
      assert_equal "owner", proposal.lane
      assert_equal users(:employee), proposal.proposer
    end

    test "mixed non-owner edit produces two proposals, one per lane" do
      result = nil
      assert_difference("ChangeProposal.count", 2) do
        result = Editor.call(asset: systems(:tracker), actor: users(:employee),
                             attributes: { department: "Product", criticality: "low" })
      end
      assert_equal %w[compliance owner], result.value.proposals.map(&:lane).sort
      assert_equal 2, AuditEvent.where(event_type: "proposal.created").count
    end

    test "proposal creation notifies reviewers by lane, minus the proposer" do
      # owner lane on acme → owner + delegate (2 mails)
      assert_enqueued_emails 2 do
        Editor.call(asset: vendors(:acme), actor: users(:employee), attributes: { description: "a" })
      end
      # compliance lane (owner's ⚖ edit) → the one compliance user
      assert_enqueued_emails 1 do
        Editor.call(asset: vendors(:acme), actor: users(:owner), attributes: { data_location: "us" })
      end
    end

    test "risk_tier is not even proposable — whole edit fails" do
      result = nil
      assert_no_difference([ "AuditEvent.count", "ChangeProposal.count" ]) do
        result = Editor.call(asset: vendors(:acme), actor: users(:owner),
                             attributes: { description: "sneaky", risk_tier: "low" })
      end
      assert_not result.success
      assert_equal :not_permitted, result.code
      assert_includes result.context[:fields], "risk_tier"
      assert_equal "Object storage and CDN.", vendors(:acme).reload.description
    end

    test "status of a pending asset is not proposable" do
      result = Editor.call(asset: vendors(:pending_vendor), actor: users(:employee),
                           attributes: { status: "active" })
      assert_not result.success
      assert_equal :not_permitted, result.code
      assert_equal "pending_approval", vendors(:pending_vendor).reload.status
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
