require "test_helper"

class AuditViewerTest < ActionDispatch::IntegrationTest
  test "members get no access" do
    sign_in_as users(:employee)
    get audit_events_path
    assert_response :forbidden
  end

  test "compliance and admin see the log" do
    sign_in_as users(:owner)
    patch vendor_path(vendors(:acme)), params: { vendor: { description: "for the log" } }
    delete logout_path

    [ users(:compliance), users(:admin) ].each do |viewer|
      sign_in_as viewer
      get audit_events_path
      assert_response :success
      assert_includes response.body, "vendor.updated"
      assert_includes response.body, "for the log"
      delete logout_path
    end
  end

  test "filters narrow by event type and actor" do
    sign_in_as users(:owner)
    patch vendor_path(vendors(:acme)), params: { vendor: { description: "owner change" } }
    delete logout_path

    sign_in_as users(:compliance)
    patch system_path(systems(:tracker)), params: { system: { criticality: "low" } }

    # Event names also appear as filter <option>s, so assert on row contents
    # (the rendered attribute diffs), not on the event names themselves.
    get audit_events_path(event_type: "vendor.updated")
    assert_includes response.body, "owner change"
    assert_not_includes response.body, "Criticality"

    get audit_events_path(actor_id: users(:owner).id)
    assert_includes response.body, "owner change"
    assert_not_includes response.body, "Criticality"
  end

  # acme is risk_tier "medium"; assessing it at "medium" again is the confirming
  # re-review that used to render as a bare "medium → medium" diff.
  test "a completed assessment shows its outcome, not a risk-tier diff" do
    sign_in_as users(:compliance)
    post vendor_assessments_path(vendors(:acme))
    assessment = Assessment.in_progress.sole
    patch complete_vendor_assessment_path(vendors(:acme), assessment), params: {
      residual_risk: "medium", decision: "approved", next_review_on: Date.current + 2.years
    }

    get audit_events_path(event_type: "assessment.completed")
    assert_response :success
    assert_includes response.body, "Residual risk"
    assert_includes response.body, "Decision"
    assert_includes response.body, "Approved"
    assert_includes response.body, (Date.current + 2.years).strftime("%b %-d, %Y")
    assert_not_includes response.body, "→ Medium"
    assert_not_includes response.body, "medium → medium"
  end

  test "a started assessment reports its inherent risk instead of an empty cell" do
    sign_in_as users(:compliance)
    post vendor_assessments_path(vendors(:acme))

    get audit_events_path(event_type: "assessment.started")
    assert_response :success
    assert_includes response.body, "Inherent risk"
  end

  test "an assessment target names itself without repeating the vendor" do
    sign_in_as users(:compliance)
    post vendor_assessments_path(vendors(:acme))
    assessment = Assessment.sole

    get audit_events_path(event_type: "assessment.started")
    assert_response :success
    assert_includes response.body, "risk assessment"
    assert_not_includes response.body, "assessment of Acme Cloud"
    assert_includes response.body, vendor_assessment_path(vendors(:acme), assessment)
  end
end
