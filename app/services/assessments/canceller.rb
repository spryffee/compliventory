module Assessments
  # Cancels (abandons) an in-progress assessment: the row is destroyed
  # (hard-delete philosophy) and the audit event keeps a full snapshot, so the
  # attempt survives the row. Completed records are never cancelled — they're the
  # permanent deliverable.
  class Canceller < ApplicationService
    def initialize(assessment:, actor:)
      @assessment = assessment
      @actor = actor
    end

    def call
      return failure(:not_permitted) unless AssessmentPolicy.new(@actor, @assessment).may_cancel?
      return failure(:not_in_progress) unless @assessment.in_progress?

      vendor = @assessment.asset
      snapshot = @assessment.attributes

      ActiveRecord::Base.transaction do
        @assessment.destroy!
        AuditEvent.record!(
          event_type: "assessment.cancelled",
          actor: @actor,
          targets: vendor,
          metadata: { "source" => "web-ui", "snapshot" => snapshot }
        )
      end

      success(@assessment)
    end
  end
end
