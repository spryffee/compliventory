require "test_helper"

module Assessments
  class LifecycleTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      Current.correlation_id = SecureRandom.uuid
      @vendor = vendors(:acme)
      @compliance = users(:compliance)
    end

    teardown { Current.reset }

    # --- Starter -------------------------------------------------------------

    test "start snapshots inherent risk, seeds the checklist, and audits" do
      result = Starter.call(vendor: @vendor, actor: @compliance)
      assert result.success

      assessment = result.value
      assert_equal "in_progress", assessment.status
      assert_equal @compliance, assessment.assessor
      # acme: cloud_infra + PII vendor + a confidential/high system → high.
      assert_equal "high", assessment.inherent_risk
      assert assessment.inherent_risk_factors.any?
      assert_equal Assessment::EVIDENCE_KINDS, assessment.evidence.map { |i| i["kind"] }

      event = AuditEvent.where(event_type: "assessment.started").sole
      assert_equal @vendor.id, event.target_id("Vendor")
    end

    test "only compliance may start, not pending vendors, and not twice" do
      assert_equal :not_permitted, Starter.call(vendor: @vendor, actor: users(:owner)).code
      assert_equal :not_assessable, Starter.call(vendor: vendors(:pending_vendor), actor: @compliance).code

      Starter.call(vendor: @vendor, actor: @compliance)
      assert_equal :already_in_progress, Starter.call(vendor: @vendor, actor: @compliance).code
    end

    # --- Updater -------------------------------------------------------------

    test "update saves summary and upserts an evidence row by kind without auditing" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value

      assert_no_difference "AuditEvent.count" do
        result = Updater.call(
          assessment: assessment, actor: @compliance, summary: "Reviewed the SOC 2.",
          evidence_item: { kind: "soc2_report", state: "reviewed", url: "https://trust.acme/soc2", notes: "clean" }
        )
        assert result.success
      end

      assessment.reload
      assert_equal "Reviewed the SOC 2.", assessment.summary
      soc2 = assessment.evidence.find { |i| i["kind"] == "soc2_report" }
      assert_equal "reviewed", soc2["state"]
      assert_equal "https://trust.acme/soc2", soc2["url"]
    end

    test "update rejects an unknown evidence kind or state" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value

      assert_equal :invalid_evidence,
                   Updater.call(assessment: assessment, actor: @compliance, evidence_item: { kind: "bribe", state: "reviewed" }).code
      assert_equal :invalid_evidence,
                   Updater.call(assessment: assessment, actor: @compliance, evidence_item: { kind: "dpa", state: "signed" }).code
    end

    test "update is refused on a non-compliance actor and on completed records" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value
      assert_equal :not_permitted, Updater.call(assessment: assessment, actor: users(:owner), summary: "x").code

      complete!(assessment)
      assert_equal :not_in_progress, Updater.call(assessment: assessment, actor: @compliance, summary: "x").code
    end

    # --- Completer -----------------------------------------------------------

    test "completion freezes the record and writes residual risk back to the vendor" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value
      review_date = Date.current + 1.year

      result = Completer.call(
        assessment: assessment, actor: @compliance,
        residual_risk: "low", decision: "approved", next_review_on: review_date
      )
      assert result.success

      assessment.reload
      assert assessment.completed?
      assert_not_nil assessment.completed_at

      @vendor.reload
      assert_equal "low", @vendor.risk_tier
      assert_equal Date.current, @vendor.last_assessed_on
      assert_equal review_date, @vendor.next_review_on

      event = AuditEvent.where(event_type: "assessment.completed").sole
      assert_equal({ "risk_tier" => [ "medium", "low" ] }, event.attribute_changes)
      assert_equal "approved", event.metadata["decision"]
    end

    test "completion requires residual risk, decision and next review date" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value
      result = Completer.call(assessment: assessment, actor: @compliance,
                              residual_risk: nil, decision: nil, next_review_on: nil)

      assert_equal :validation_failed, result.code
      assert assessment.reload.in_progress?, "a failed completion must not mutate the record"
      assert_equal "medium", @vendor.reload.risk_tier, "a failed completion must not touch the vendor"
    end

    test "approved_with_conditions requires conditions text" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value
      result = Completer.call(assessment: assessment, actor: @compliance, residual_risk: "medium",
                              decision: "approved_with_conditions", next_review_on: Date.current + 1.year)
      assert_equal :validation_failed, result.code

      ok = Completer.call(assessment: assessment.reload, actor: @compliance, residual_risk: "medium",
                          decision: "approved_with_conditions", conditions: "Sign a DPA within 30 days",
                          next_review_on: Date.current + 1.year)
      assert ok.success
    end

    test "only compliance may complete" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value
      assert_equal :not_permitted,
                   Completer.call(assessment: assessment, actor: users(:owner), residual_risk: "low",
                                  decision: "approved", next_review_on: Date.current + 1.year).code
    end

    test "completion notifies the vendor owner" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value # acme owner is Oscar, not the assessor
      assert_enqueued_emails 1 do
        Completer.call(assessment: assessment, actor: @compliance, residual_risk: "low",
                       decision: "approved", next_review_on: Date.current + 1.year)
      end
    end

    test "no owner notification when the owner runs the assessment themselves" do
      vendor = Vendor.create!(name: "Self-owned Co", owner: @compliance, status: "active")
      assessment = Starter.call(vendor: vendor, actor: @compliance).value
      assert_no_enqueued_emails do
        Completer.call(assessment: assessment, actor: @compliance, residual_risk: "low",
                       decision: "approved", next_review_on: Date.current + 1.year)
      end
    end

    # --- Canceller -----------------------------------------------------------

    test "cancel destroys the row and keeps a snapshot in the audit event" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value

      assert_difference "Assessment.count", -1 do
        result = Canceller.call(assessment: assessment, actor: @compliance)
        assert result.success
      end

      event = AuditEvent.where(event_type: "assessment.cancelled").sole
      assert_equal @vendor.id, event.target_id("Vendor")
      assert_equal "in_progress", event.metadata["snapshot"]["status"]
    end

    test "cancel is refused for non-compliance and for completed records" do
      assessment = Starter.call(vendor: @vendor, actor: @compliance).value
      assert_equal :not_permitted, Canceller.call(assessment: assessment, actor: users(:owner)).code

      complete!(assessment)
      assert_equal :not_in_progress, Canceller.call(assessment: assessment, actor: @compliance).code
    end

    private

    def complete!(assessment)
      Completer.call(assessment: assessment, actor: @compliance, residual_risk: "low",
                     decision: "approved", next_review_on: Date.current + 1.year)
      assessment.reload
    end
  end
end
