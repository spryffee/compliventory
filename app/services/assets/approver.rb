module Assets
  # Compliance approves a submitted (pending_approval) asset: the only path
  # from pending_approval to active.
  class Approver < ApplicationService
    def initialize(asset:, actor:, comment: nil)
      @asset = asset
      @actor = actor
      @comment = comment
    end

    def call
      return failure(:not_permitted) unless @actor.compliance?
      return failure(:not_pending) unless @asset.pending_approval?

      ActiveRecord::Base.transaction do
        @asset.update!(status: "active")
        AuditEvent.record!(
          event_type: "#{@asset.audit_event_prefix}.approved",
          actor: @actor,
          targets: @asset,
          attribute_changes: { "status" => [ "pending_approval", "active" ] },
          justification: @comment.presence,
          metadata: { "source" => "web-ui", "decision" => "approved" }
        )
      end

      notify_owner
      success(@asset)
    end

    private

    def notify_owner
      owner = @asset.owner
      return if owner == @actor || !owner.active?

      AssetMailer.with(
        recipient: owner, decision: "approved", decided_by: @actor.name,
        asset_type: @asset.class.name, asset_id: @asset.id, asset_name: @asset.name,
        comment: @comment.presence
      ).decided.deliver_later
    end
  end
end
