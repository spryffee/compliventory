require "test_helper"

class AuditHelperTest < ActionView::TestCase
  # Audit events are never mutated, so building them unsaved is enough here.
  def event(type, metadata)
    AuditEvent.new(event_type: type, metadata: metadata)
  end

  test "a completion that moved the tier reports the previous level" do
    lines = audit_outcome(event("assessment.completed",
      { "residual_risk" => "high", "previous_risk_tier" => "medium",
        "decision" => "approved_with_conditions", "next_review_on" => "2027-06-28" }))

    assert_equal [
      [ "Residual risk", "High (was Medium)" ],
      [ "Decision", "Approved with conditions" ],
      [ "Next review", "Jun 28, 2027" ]
    ], lines
  end

  test "a re-review confirming the tier reads as an assignment, not 'high → high'" do
    lines = audit_outcome(event("assessment.completed",
      { "residual_risk" => "high", "previous_risk_tier" => "high", "decision" => "approved" }))

    assert_equal [ "Residual risk", "High" ], lines.first
  end

  test "a first assessment has no previous tier to report" do
    lines = audit_outcome(event("assessment.completed",
      { "residual_risk" => "low", "previous_risk_tier" => nil, "decision" => "approved" }))

    assert_equal [ "Residual risk", "Low" ], lines.first
  end

  # The audit log is append-only: events written before previous_risk_tier
  # existed must still render, just without the parenthetical.
  test "completions recorded before previous_risk_tier existed still render" do
    lines = audit_outcome(event("assessment.completed",
      { "residual_risk" => "high", "decision" => "approved" }))

    assert_equal [ [ "Residual risk", "High" ], [ "Decision", "Approved" ] ], lines
  end

  test "a started assessment reports the inherent risk it snapshotted" do
    assert_equal [ [ "Inherent risk", "High" ] ],
                 audit_outcome(event("assessment.started", { "inherent_risk" => "high" }))
    assert_equal [ [ "Inherent risk", "Unscored" ] ],
                 audit_outcome(event("assessment.started", { "inherent_risk" => nil }))
  end

  test "a cancelled assessment says so instead of rendering an empty cell" do
    assert_equal [ [ nil, "Abandoned — no outcome recorded" ] ],
                 audit_outcome(event("assessment.cancelled", { "snapshot" => { "id" => "x" } }))
  end

  test "an assessment target links to the assessment under its vendor" do
    vendor_id, assessment_id = SecureRandom.uuid, SecureRandom.uuid
    event = AuditEvent.new(event_type: "assessment.completed", targets: [
      { "type" => "Assessment", "id" => assessment_id, "display" => "risk assessment" },
      { "type" => "Vendor", "id" => vendor_id, "display" => "Slacker" }
    ])

    html = audit_target_tag(event.targets.first, event)
    assert_includes html, "/vendors/#{vendor_id}/assessments/#{assessment_id}"
    assert_includes html, "risk assessment"
    # The co-target still names the vendor — that is why the assessment must not.
    assert_includes audit_target_tag(event.targets.second, event), "/vendors/#{vendor_id}"
  end

  test "an assessment target with no vendor co-target renders unlinked, not broken" do
    event = AuditEvent.new(event_type: "assessment.completed", targets: [
      { "type" => "Assessment", "id" => SecureRandom.uuid, "display" => "risk assessment" }
    ])

    html = audit_target_tag(event.targets.first, event)
    assert_not_includes html, "<a"
    assert_includes html, "risk assessment"
  end

  # Metadata is rendered per event type on purpose — it also holds internals
  # (snapshots, proposal_id, api_token_id) that must never reach the UI.
  test "events carrying a real field diff get no metadata rendering" do
    assert_empty audit_outcome(event("vendor.updated", { "source" => "web-ui" }))
    assert_empty audit_outcome(event("proposal.approved", { "proposal_id" => "x", "lane" => "owner" }))
    assert_empty audit_outcome(event("vendor.rejected", { "snapshot" => { "name" => "secret" } }))
    assert_empty audit_outcome(event("vendor.updated", nil))
  end
end
