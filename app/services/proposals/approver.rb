module Proposals
  # Approving applies the proposed values and destroys the proposal row; the
  # full story (diff, decision, comment, actor) lives in the audit event.
  # Stale base values are the reviewer's call — the review screen showed
  # base → current → proposed; approving applies the proposed value.
  class Approver < ApplicationService
    def initialize(proposal:, actor:, comment: nil)
      @proposal = proposal
      @actor = actor
      @comment = comment
    end

    def call
      return failure(:not_permitted) unless ProposalPolicy.new(@actor, @proposal).may_decide?

      asset = @proposal.asset
      applied = nil

      ActiveRecord::Base.transaction do
        asset.assign_attributes(@proposal.proposed_attributes)
        applied = asset.changes.except("created_at", "updated_at")
        asset.save!
        @proposal.destroy!
        AuditEvent.record!(
          event_type: "proposal.approved",
          actor: @actor,
          targets: asset,
          attribute_changes: applied,
          justification: @comment.presence,
          metadata: proposal_metadata.merge("decision" => "approved")
        )
      end

      notify_proposer("approved", asset)
      success(asset)
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end

    private

    def proposal_metadata
      {
        "source" => "web-ui",
        "proposal_id" => @proposal.id,
        "lane" => @proposal.lane,
        "proposer_id" => @proposal.proposer_id,
        "proposer" => @proposal.proposer.audit_display,
        "proposed_changes" => @proposal.attribute_changes
      }
    end

    def notify_proposer(decision, asset)
      proposer = @proposal.proposer
      return if proposer == @actor || !proposer.active?

      ProposalMailer.with(
        recipient: proposer, decision: decision, decided_by: @actor.name,
        asset_type: asset.class.name, asset_id: asset.id, asset_name: asset.name,
        changes: @proposal.attribute_changes, comment: @comment.presence
      ).decided.deliver_later
    end
  end
end
