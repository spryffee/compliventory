module Assessments
  # Completes an in-progress assessment: freezes it into a compliance record and
  # writes the outcome back onto the vendor — residual risk becomes the vendor's
  # risk_tier, and the review dates are stamped. One transaction, one audit event
  # carrying the risk_tier change. The model enforces that a completed record
  # carries residual_risk, decision and next_review_on (and conditions when the
  # decision is approved_with_conditions), so a bad payload fails the save.
  class Completer < ApplicationService
    def initialize(assessment:, actor:, residual_risk:, decision:, next_review_on:, conditions: nil)
      @assessment = assessment
      @actor = actor
      @residual_risk = residual_risk
      @decision = decision
      @next_review_on = next_review_on
      @conditions = conditions
    end

    def call
      return failure(:not_permitted) unless AssessmentPolicy.new(@actor, @assessment).may_complete?
      return failure(:not_in_progress) unless @assessment.in_progress?

      vendor = @assessment.asset
      tier_change = [ vendor.risk_tier, @residual_risk ]

      ActiveRecord::Base.transaction do
        @assessment.update!(
          status: "completed",
          residual_risk: @residual_risk,
          decision: @decision,
          conditions: @conditions.presence,
          next_review_on: @next_review_on,
          completed_at: Time.current
        )
        vendor.update!(
          risk_tier: @residual_risk,
          last_assessed_on: Date.current,
          next_review_on: @next_review_on
        )
        AuditEvent.record!(
          event_type: "assessment.completed",
          actor: @actor,
          targets: [ @assessment, vendor ],
          attribute_changes: { "risk_tier" => tier_change },
          metadata: {
            "source" => "web-ui",
            "decision" => @decision,
            "residual_risk" => @residual_risk,
            "inherent_risk" => @assessment.inherent_risk,
            "next_review_on" => @assessment.next_review_on.to_s
          }
        )
      end

      success(@assessment)
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end
  end
end
