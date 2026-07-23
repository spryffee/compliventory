require "test_helper"

class AssessmentTest < ActiveSupport::TestCase
  setup do
    @vendor = vendors(:acme)
    @assessor = users(:compliance)
  end

  def build(**overrides)
    Assessment.new({ asset: @vendor, assessor: @assessor, status: "in_progress" }.merge(overrides))
  end

  test "a minimal in-progress assessment is valid" do
    assert build.valid?
  end

  test "requires a known status" do
    assert_not build(status: "archived").valid?
  end

  test "risk levels and decision are validated but nil-able (unset until completion)" do
    assert build(inherent_risk: nil, residual_risk: nil, decision: nil).valid?
    assert_not build(inherent_risk: "extreme").valid?
    assert_not build(residual_risk: "extreme").valid?
    assert_not build(decision: "maybe").valid?
    assert build(inherent_risk: "high", residual_risk: "low", decision: "approved").valid?
  end

  test "conditions are required only when the decision is approved_with_conditions" do
    assert_not build(decision: "approved_with_conditions", conditions: nil).valid?
    assert build(decision: "approved_with_conditions", conditions: "Sign a DPA").valid?
    assert build(decision: "approved", conditions: nil).valid?
  end

  test "a completed record must carry residual risk, decision and next review date" do
    assessment = build.tap(&:save!)
    assessment.status = "completed"
    assert_not assessment.valid?
    assert_includes assessment.errors.attribute_names, :residual_risk
    assert_includes assessment.errors.attribute_names, :decision
    assert_includes assessment.errors.attribute_names, :next_review_on
  end

  test "the completion transition is allowed but later edits to a completed record are rejected" do
    assessment = build.tap(&:save!)

    assessment.update!(status: "completed", residual_risk: "low", decision: "approved", next_review_on: Date.current)

    assessment.summary = "tampering after the fact"
    assert_not assessment.valid?
    assert_includes assessment.errors[:base], "completed assessments cannot be modified"
  end

  test "at most one in-progress assessment per asset (partial unique index)" do
    build.save!
    assert_raises(ActiveRecord::RecordNotUnique) { build.save!(validate: false) }
  end

  test "a completed assessment does not block a fresh in-progress one for the same asset" do
    build.tap(&:save!).update!(status: "completed", residual_risk: "low", decision: "approved", next_review_on: Date.current)
    assert build.valid?
    assert_nothing_raised { build.save! }
  end

  test "scopes select by status and asset" do
    in_progress = build.tap(&:save!)
    done = Assessment.create!(asset: vendors(:pending_vendor), assessor: @assessor, status: "completed",
                              residual_risk: "low", decision: "approved", next_review_on: Date.current)

    assert_includes Assessment.in_progress, in_progress
    assert_not_includes Assessment.in_progress, done
    assert_includes Assessment.completed, done
    assert_equal [ in_progress ], Assessment.for_asset(@vendor).to_a
  end

  test "blank_evidence has one pending item per document kind" do
    evidence = Assessment.blank_evidence

    assert_equal Assessment::EVIDENCE_KINDS, evidence.map { |item| item["kind"] }
    assert(evidence.all? { |item| item["state"] == "pending" })
    assert(evidence.all? { |item| item.key?("url") && item.key?("notes") })
  end
end
