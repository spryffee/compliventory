module Assets
  # New assets are not proposals: a submission creates the real vendor/system
  # row (DESIGN.md). Member submissions start as pending_approval; a compliance
  # submitter is the approver, so their submission is self-approved and starts
  # active. Compliance-set-only fields (risk_tier) are stripped from
  # non-compliance submissions — not even proposable.
  class Submitter < ApplicationService
    def initialize(asset_class:, actor:, attributes:)
      @asset_class = asset_class
      @actor = actor
      @attributes = attributes
    end

    def call
      asset = @asset_class.new(@attributes)
      unless @actor.compliance?
        @asset_class::COMPLIANCE_SET_ONLY_FIELDS.each { |field| asset[field] = nil }
      end
      asset.status = @actor.compliance? ? "active" : "pending_approval"

      ActiveRecord::Base.transaction do
        asset.save!
        AuditEvent.record!(
          event_type: "#{asset.audit_event_prefix}.submitted",
          actor: @actor,
          targets: asset,
          metadata: { "source" => "web-ui", "status" => asset.status }
        )
      end

      notify_compliance(asset)
      success(asset)
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end

    private

    def notify_compliance(asset)
      return unless asset.pending_approval?

      User.active.where(role: "compliance").find_each do |reviewer|
        AssetMailer.with(recipient: reviewer, asset: asset, submitter: @actor).submitted.deliver_later
      end
    end
  end
end
