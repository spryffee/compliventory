module Proposals
  # Rejecting destroys the proposal row; the audit event keeps the full
  # proposed diff so nothing is lost with the row.
  class Rejecter < ApplicationService
    def initialize(proposal:, actor:, comment: nil)
      @proposal = proposal
      @actor = actor
      @comment = comment
    end

    def call
      return failure(:not_permitted) unless ProposalPolicy.new(@actor, @proposal).may_decide?

      asset = @proposal.asset

      ActiveRecord::Base.transaction do
        @proposal.destroy!
        AuditEvent.record!(
          event_type: "proposal.rejected",
          actor: @actor,
          targets: asset,
          attribute_changes: @proposal.attribute_changes,
          justification: @comment.presence,
          metadata: @proposal.audit_identity.merge("source" => "web-ui", "decision" => "rejected")
        )
      end

      notify_proposer(asset)
      success(asset)
    end

    private

    def notify_proposer(asset)
      proposer = @proposal.proposer
      return unless notify?(proposer, @actor)

      ProposalMailer.with(
        recipient: proposer, decision: "rejected", decided_by: @actor.name,
        asset_type: asset.class.name, asset_id: asset.id, asset_name: asset.name,
        changes: @proposal.attribute_changes, comment: @comment.presence
      ).decided.deliver_later
    end
  end
end
