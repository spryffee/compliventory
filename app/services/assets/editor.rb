module Assets
  # Direct-path editor: applies the fields the actor may edit directly and
  # audits the diff in the same transaction. Fields the actor may NOT edit
  # directly fail the whole edit here — the change-control phase will route
  # them into proposal lanes instead of rejecting them.
  class Editor < ApplicationService
    def initialize(asset:, actor:, attributes:)
      @asset = asset
      @actor = actor
      @attributes = attributes
    end

    def call
      policy = AssetPolicy.for(@actor, @asset)

      @asset.assign_attributes(@attributes)
      changes = @asset.changes.except("created_at", "updated_at")
      return success(@asset) if changes.empty?

      denied = changes.keys.reject { |field| policy.editable_directly?(field) }
      if denied.any?
        @asset.restore_attributes
        return failure(:not_permitted, fields: denied)
      end

      ActiveRecord::Base.transaction do
        @asset.save!
        AuditEvent.record!(
          event_type: "#{@asset.audit_event_prefix}.updated",
          actor: @actor,
          targets: @asset,
          attribute_changes: changes,
          metadata: { "source" => "web-ui" }
        )
      end

      success(@asset)
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end
  end
end
