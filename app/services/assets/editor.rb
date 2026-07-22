module Assets
  # One edit path for everything; the diff is routed per field and actor
  # (DESIGN.md, "Change-control mechanics"):
  #
  #   actor is compliance ──────────────→ apply all, audit
  #   ⚖ fields in diff ────────────────→ change_proposal(lane: compliance)
  #   regular fields in diff
  #     actor is owner/delegate ───────→ apply, audit
  #     otherwise ─────────────────────→ change_proposal(lane: owner)
  #
  # A mixed edit thus applies part of the diff directly and turns the rest into
  # up to two proposals (one per lane), each approvable independently. Fields
  # that may not even be proposed (risk_tier for non-compliance, status of a
  # pending asset) fail the whole edit.
  class Editor < ApplicationService
    Outcome = Data.define(:asset, :applied_changes, :proposals)

    def initialize(asset:, actor:, attributes:, justification: nil)
      @asset = asset
      @actor = actor
      @attributes = attributes
      @justification = justification
    end

    def call
      policy = AssetPolicy.for(@actor, @asset)

      @asset.assign_attributes(@attributes)
      diff = @asset.changes.except("created_at", "updated_at")

      # A blank form input submits "" where the column is nil — Rails dirty
      # tracking flags that as a change (nil → ""), but nothing meaningful moved.
      # Drop such blank↔blank no-ops so they're neither saved nor audited/proposed
      # (restore reverts the in-memory value to the stored one).
      noop = diff.select { |_, (old, new)| old.blank? && new.blank? }.keys
      if noop.any?
        @asset.restore_attributes(noop)
        diff = diff.except(*noop)
      end

      return success(Outcome.new(asset: @asset, applied_changes: {}, proposals: [])) if diff.empty?

      denied = diff.keys.reject { |field| policy.editable_directly?(field) || policy.proposable?(field) }
      if denied.any?
        @asset.restore_attributes
        return failure(:not_permitted, fields: denied)
      end

      direct = diff.select { |field, _| policy.editable_directly?(field) }
      proposed = diff.except(*direct.keys)

      # Proposed fields stay at their current value on the record; only the
      # direct part is written.
      @asset.restore_attributes(proposed.keys)

      proposals = []
      ActiveRecord::Base.transaction do
        if direct.any?
          @asset.save!
          AuditEvent.record!(
            event_type: "#{@asset.audit_event_prefix}.updated",
            actor: @actor,
            targets: @asset,
            attribute_changes: direct,
            metadata: { "source" => "web-ui" }
          )
        end

        proposed.group_by { |field, _| lane_for(field) }.each do |lane, fields|
          proposal = ChangeProposal.create!(
            asset: @asset, proposer: @actor, lane: lane,
            attribute_changes: fields.to_h, justification: @justification.presence
          )
          AuditEvent.record!(
            event_type: "proposal.created",
            actor: @actor,
            targets: @asset,
            attribute_changes: proposal.attribute_changes,
            justification: @justification.presence,
            metadata: { "source" => "web-ui", "lane" => lane, "proposal_id" => proposal.id }
          )
          proposals << proposal
        end
      end

      notify_reviewers(proposals)
      success(Outcome.new(asset: @asset, applied_changes: direct, proposals: proposals))
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end

    private

    def lane_for(field)
      @asset.class::COMPLIANCE_FIELDS.include?(field.to_sym) ? "compliance" : "owner"
    end

    def notify_reviewers(proposals)
      proposals.each do |proposal|
        proposal.reviewers.each do |reviewer|
          ProposalMailer.with(proposal: proposal, recipient: reviewer).created.deliver_later
        end
      end
    end
  end
end
