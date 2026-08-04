module Assessments
  # Completes an in-progress assessment: freezes it into a compliance record and
  # writes the outcome back onto the vendor — residual risk becomes the vendor's
  # risk_tier, and the review dates are stamped. One transaction, one audit event
  # carrying the whole outcome in metadata (the assigned tier is a review result,
  # not a field edit, so it is NOT an attribute_changes diff — a re-review that
  # confirms the tier is a real outcome, not a no-op). The model enforces that a
  # completed record
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
      previous_tier = vendor.risk_tier

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
          metadata: {
            "source" => "web-ui",
            "decision" => @decision,
            "residual_risk" => @residual_risk,
            "previous_risk_tier" => previous_tier,
            "inherent_risk" => @assessment.inherent_risk,
            "next_review_on" => @assessment.next_review_on.to_s
          }
        )
      end

      notify_owner(vendor)
      success(@assessment)
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end

    private

    def notify_owner(vendor)
      owner = vendor.owner
      return unless notify?(owner, @actor)

      AssessmentMailer.with(recipient: owner, assessor: @actor.name, assessment: @assessment)
                      .completed.deliver_later
    end
  end
end
