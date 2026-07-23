require "test_helper"

class AssessmentsTest < ActionDispatch::IntegrationTest
  setup { @vendor = vendors(:acme) }

  # --- Risk panel on the vendor page ---------------------------------------

  test "the vendor page shows the computed inherent risk and a start button for compliance" do
    sign_in_as users(:compliance)
    get vendor_path(@vendor)

    assert_includes response.body, "Inherent risk"
    assert_includes response.body, "Start assessment"
  end

  test "a member sees the risk panel but no start button" do
    sign_in_as users(:owner)
    get vendor_path(@vendor)

    assert_includes response.body, "Inherent risk"
    assert_not_includes response.body, "Start assessment"
  end

  # --- Lifecycle through the UI --------------------------------------------

  test "compliance starts, fills, and completes an assessment; the vendor gets the residual risk" do
    sign_in_as users(:compliance)

    assert_difference("Assessment.count", 1) do
      post vendor_assessments_path(@vendor)
    end
    assessment = @vendor.assessments.sole
    assert_redirected_to vendor_assessment_path(@vendor, assessment)

    # fill an evidence row and the findings
    patch vendor_assessment_path(@vendor, assessment),
          params: { evidence_item: { kind: "soc2_report", state: "reviewed", url: "https://trust.acme/soc2" } }
    patch vendor_assessment_path(@vendor, assessment), params: { summary: "SOC 2 clean, no exceptions." }

    assessment.reload
    assert_equal "reviewed", assessment.evidence.find { |i| i["kind"] == "soc2_report" }["state"]
    assert_equal "SOC 2 clean, no exceptions.", assessment.summary

    # complete
    patch complete_vendor_assessment_path(@vendor, assessment),
          params: { residual_risk: "low", decision: "approved", next_review_on: (Date.current + 1.year).to_s }
    assert_redirected_to vendor_assessment_path(@vendor, assessment)

    assert @vendor.reload.risk_tier == "low"
    assert_equal Date.current, @vendor.last_assessed_on
    assert assessment.reload.completed?
  end

  test "an in-progress assessment page renders the editable checklist and completion form" do
    assessment = start_an_assessment
    sign_in_as users(:compliance)
    get vendor_assessment_path(@vendor, assessment)

    assert_response :ok
    assert_includes response.body, "Evidence reviewed"
    assert_includes response.body, "evidence_item[state]"
    assert_includes response.body, "Complete assessment"
  end

  test "a completed assessment page is read-only — no edit or complete forms" do
    assessment = complete_an_assessment

    sign_in_as users(:compliance)
    get vendor_assessment_path(@vendor, assessment)

    assert_includes response.body, "Outcome"
    assert_not_includes response.body, "Complete assessment"
    assert_not_includes response.body, "evidence_item[state]"
  end

  test "cancelling destroys the in-progress assessment" do
    sign_in_as users(:compliance)
    post vendor_assessments_path(@vendor)
    assessment = @vendor.assessments.sole

    assert_difference("Assessment.count", -1) do
      delete vendor_assessment_path(@vendor, assessment)
    end
    assert_redirected_to vendor_path(@vendor)
  end

  # --- Authorization --------------------------------------------------------

  test "a non-compliance user cannot start or edit assessments" do
    sign_in_as users(:owner)
    post vendor_assessments_path(@vendor)
    assert_response :forbidden
    assert_equal 0, @vendor.assessments.count
  end

  test "a non-compliance user cannot complete an assessment" do
    started = start_an_assessment
    sign_in_as users(:owner)

    patch complete_vendor_assessment_path(@vendor, started),
          params: { residual_risk: "low", decision: "approved", next_review_on: (Date.current + 1.year).to_s }
    assert_response :forbidden
    assert started.reload.in_progress?
  end

  private

  def start_an_assessment
    Current.correlation_id = SecureRandom.uuid
    Assessments::Starter.call(vendor: @vendor, actor: users(:compliance)).value
  ensure
    Current.reset
  end

  def complete_an_assessment
    assessment = start_an_assessment
    Current.correlation_id = SecureRandom.uuid
    Assessments::Completer.call(assessment: assessment, actor: users(:compliance), residual_risk: "low",
                                decision: "approved", next_review_on: Date.current + 1.year)
    assessment.reload
  ensure
    Current.reset
  end
end
