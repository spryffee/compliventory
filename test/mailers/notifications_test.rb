require "test_helper"

# Renders every mail template with real data — enqueue-only assertions in the
# flow tests never execute the ERB, so template errors would slip through.
class NotificationsTest < ActionMailer::TestCase
  test "proposal created" do
    proposal = ChangeProposal.create!(
      asset: vendors(:acme), proposer: users(:employee), lane: "owner",
      attribute_changes: { "description" => [ "Object storage and CDN.", "New" ] }, justification: "why not"
    )
    mail = ProposalMailer.with(proposal: proposal, recipient: users(:owner)).created
    assert_equal [ users(:owner).email ], mail.to
    assert_match "Acme Cloud", mail.subject
    assert_match "New", mail.body.encoded
    assert_match "why not", mail.body.encoded
  end

  test "proposal decided" do
    mail = ProposalMailer.with(
      recipient: users(:employee), decision: "approved", decided_by: "Oscar Owner",
      asset_type: "Vendor", asset_id: vendors(:acme).id, asset_name: "Acme Cloud",
      changes: { "description" => [ "a", "b" ] }, comment: "fine"
    ).decided
    assert_equal [ users(:employee).email ], mail.to
    assert_match "approved", mail.subject
    assert_match "fine", mail.body.encoded
  end

  test "asset submitted" do
    mail = AssetMailer.with(
      recipient: users(:compliance), asset: vendors(:pending_vendor), submitter: users(:employee)
    ).submitted
    assert_equal [ users(:compliance).email ], mail.to
    assert_match "NewTool.io", mail.subject
    assert_match "compliance inbox", mail.body.encoded
  end

  test "asset decided — rejected has no link to the destroyed record" do
    mail = AssetMailer.with(
      recipient: users(:employee), decision: "rejected", decided_by: "Clara Compliance",
      asset_type: "Vendor", asset_id: vendors(:pending_vendor).id, asset_name: "NewTool.io",
      comment: "duplicate"
    ).decided
    assert_match "rejected", mail.subject
    assert_match "audit log", mail.body.encoded
  end

  test "assessment completed" do
    assessment = Assessment.create!(
      asset: vendors(:acme), assessor: users(:compliance), status: "completed",
      residual_risk: "medium", decision: "approved_with_conditions", conditions: "Sign an updated DPA",
      next_review_on: Date.current + 1.year, completed_at: Time.current
    )
    mail = AssessmentMailer.with(recipient: users(:owner), assessor: "Clara Compliance", assessment: assessment).completed

    assert_equal [ users(:owner).email ], mail.to
    assert_match "Acme Cloud", mail.subject
    assert_match "Approved with conditions", mail.body.encoded
    assert_match "Sign an updated DPA", mail.body.encoded
  end

  test "weekly review digest" do
    overdue = Vendor.create!(name: "Late Co", owner: users(:owner), status: "active", next_review_on: 5.days.ago)
    mail = AssessmentMailer.with(
      recipient: users(:compliance), overdue: [ overdue ], never_assessed: [ vendors(:acme) ]
    ).weekly_digest

    assert_equal [ users(:compliance).email ], mail.to
    assert_match "2 vendors need a risk review", mail.subject
    assert_match "Late Co", mail.body.encoded
    assert_match "Acme Cloud", mail.body.encoded
  end
end
