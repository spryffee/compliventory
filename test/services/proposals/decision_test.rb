require "test_helper"

module Proposals
  class DecisionTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      Current.correlation_id = SecureRandom.uuid
      @proposal = ChangeProposal.create!(
        asset: vendors(:acme), proposer: users(:employee), lane: "owner",
        attribute_changes: { "description" => [ "Object storage and CDN.", "Proposed description" ] },
        justification: "clarity"
      )
    end

    teardown do
      Current.reset
    end

    test "approve applies the proposed values, destroys the row, audits, notifies the proposer" do
      result = nil
      assert_enqueued_emails 1 do
        assert_difference("ChangeProposal.count", -1) do
          result = Approver.call(proposal: @proposal, actor: users(:owner), comment: "makes sense")
        end
      end
      assert result.success
      assert_equal "Proposed description", vendors(:acme).reload.description

      event = AuditEvent.where(event_type: "proposal.approved").sole
      assert_equal users(:owner).id, event.actor_id
      assert_equal [ "Object storage and CDN.", "Proposed description" ], event.attribute_changes["description"]
      assert_equal "makes sense", event.justification
      assert_equal "approved", event.metadata["decision"]
      assert_equal "owner", event.metadata["lane"]
      assert_equal users(:employee).id, event.metadata["proposer_id"]
    end

    test "approving a stale proposal still applies the proposed value" do
      vendors(:acme).update!(description: "Changed meanwhile")
      assert @proposal.stale?("description")

      result = Approver.call(proposal: @proposal, actor: users(:owner))
      assert result.success
      assert_equal "Proposed description", vendors(:acme).reload.description
    end

    test "approve fails on validation and keeps the proposal" do
      proposal = ChangeProposal.create!(
        asset: vendors(:pending_vendor), proposer: users(:employee), lane: "owner",
        attribute_changes: { "name" => [ "NewTool.io", "Acme Cloud" ] } # duplicate name
      )
      result = Approver.call(proposal: proposal, actor: users(:compliance))
      assert_not result.success
      assert_equal :validation_failed, result.code
      assert ChangeProposal.exists?(proposal.id)
    end

    test "reject destroys the row, audits the proposed diff, notifies the proposer" do
      result = nil
      assert_enqueued_emails 1 do
        assert_difference("ChangeProposal.count", -1) do
          result = Rejecter.call(proposal: @proposal, actor: users(:delegate), comment: "no")
        end
      end
      assert result.success
      assert_equal "Object storage and CDN.", vendors(:acme).reload.description

      event = AuditEvent.where(event_type: "proposal.rejected").sole
      assert_equal "rejected", event.metadata["decision"]
      assert_equal [ "Object storage and CDN.", "Proposed description" ], event.attribute_changes["description"]
    end

    test "unrelated members may not decide; compliance may decide owner lane" do
      result = Approver.call(proposal: @proposal, actor: users(:employee))
      assert_equal :not_permitted, result.code
      assert ChangeProposal.exists?(@proposal.id)

      assert Approver.call(proposal: @proposal, actor: users(:compliance)).success
    end

    test "only compliance decides the compliance lane" do
      proposal = ChangeProposal.create!(
        asset: vendors(:acme), proposer: users(:employee), lane: "compliance",
        attribute_changes: { "data_location" => [ "eu", "us" ] }
      )
      assert_equal :not_permitted, Approver.call(proposal: proposal, actor: users(:owner)).code
      assert Rejecter.call(proposal: proposal, actor: users(:compliance)).success
    end

    test "no self-notification when the decider is the proposer" do
      proposal = ChangeProposal.create!(
        asset: vendors(:acme), proposer: users(:compliance), lane: "compliance",
        attribute_changes: { "data_location" => [ "eu", "us" ] }
      )
      assert_no_enqueued_emails do
        Approver.call(proposal: proposal, actor: users(:compliance))
      end
    end
  end
end
