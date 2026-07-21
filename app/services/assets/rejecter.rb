module Assets
  # Compliance rejects a submitted (pending_approval) asset: the row is
  # destroyed (hard-delete philosophy) and the audit event keeps a full
  # attribute snapshot, so the history survives the row.
  class Rejecter < ApplicationService
    def initialize(asset:, actor:, comment: nil)
      @asset = asset
      @actor = actor
      @comment = comment
    end

    def call
      return failure(:not_permitted) unless @actor.compliance?
      return failure(:not_pending) unless @asset.pending_approval?

      snapshot = @asset.attributes
      owner = @asset.owner

      ActiveRecord::Base.transaction do
        @asset.destroy!
        AuditEvent.record!(
          event_type: "#{@asset.audit_event_prefix}.rejected",
          actor: @actor,
          targets: @asset,
          justification: @comment.presence,
          metadata: { "source" => "web-ui", "decision" => "rejected", "snapshot" => snapshot }
        )
      end

      notify_owner(owner, snapshot)
      success(@asset)
    end

    private

    def notify_owner(owner, snapshot)
      return if owner == @actor || !owner.active?

      AssetMailer.with(
        recipient: owner, decision: "rejected", decided_by: @actor.name,
        asset_type: @asset.class.name, asset_id: snapshot["id"], asset_name: snapshot["name"],
        comment: @comment.presence
      ).decided.deliver_later
    end
  end
end
