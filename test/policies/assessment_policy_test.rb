require "test_helper"

class AssessmentPolicyTest < ActiveSupport::TestCase
  test "only compliance may run assessment operations" do
    assessment = Assessment.new(asset: vendors(:acme), assessor: users(:compliance), status: "in_progress")

    %i[compliance].each do |role|
      policy = AssessmentPolicy.new(users(role), assessment)
      assert policy.may_assess?
      assert policy.may_edit?
      assert policy.may_complete?
      assert policy.may_cancel?
    end

    %i[owner admin employee].each do |role|
      policy = AssessmentPolicy.new(users(role), assessment)
      assert_not policy.may_assess?
      assert_not policy.may_edit?
      assert_not policy.may_complete?
      assert_not policy.may_cancel?
    end
  end
end
