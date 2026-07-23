module Assessments
  # Compliance starts a risk assessment on a vendor. The inherent risk is
  # computed from the inventory and snapshotted onto the row (frozen for the
  # record); the evidence checklist starts blank. At most one assessment may be
  # in progress per vendor (enforced by a partial unique index — the rescue
  # covers the race).
  class Starter < ApplicationService
    def initialize(vendor:, actor:)
      @vendor = vendor
      @actor = actor
    end

    def call
      return failure(:not_permitted) unless AssessmentPolicy.new(@actor).may_assess?
      return failure(:not_assessable) if @vendor.pending_approval?
      return failure(:already_in_progress) if @vendor.assessments.in_progress.exists?

      risk = InherentRisk.call(@vendor)
      assessment = nil

      ActiveRecord::Base.transaction do
        assessment = @vendor.assessments.create!(
          assessor: @actor,
          status: "in_progress",
          inherent_risk: risk[:level],
          inherent_risk_factors: risk[:factors],
          evidence: Assessment.blank_evidence
        )
        AuditEvent.record!(
          event_type: "assessment.started",
          actor: @actor,
          targets: [ assessment, @vendor ],
          metadata: { "source" => "web-ui", "inherent_risk" => risk[:level] }
        )
      end

      success(assessment)
    rescue ActiveRecord::RecordNotUnique
      failure(:already_in_progress)
    end
  end
end
