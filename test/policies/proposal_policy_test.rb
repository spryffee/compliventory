require "test_helper"

class ProposalPolicyTest < ActiveSupport::TestCase
  def proposal(lane)
    ChangeProposal.new(asset: vendors(:acme), proposer: users(:employee), lane: lane,
                       attribute_changes: { "notes" => [ nil, "x" ] })
  end

  test "owner lane: owner, delegate and compliance decide; others don't" do
    assert ProposalPolicy.new(users(:owner), proposal("owner")).may_decide?
    assert ProposalPolicy.new(users(:delegate), proposal("owner")).may_decide?
    assert ProposalPolicy.new(users(:compliance), proposal("owner")).may_decide?
    assert_not ProposalPolicy.new(users(:employee), proposal("owner")).may_decide?
    assert_not ProposalPolicy.new(users(:admin), proposal("owner")).may_decide?
  end

  test "compliance lane: compliance only" do
    assert ProposalPolicy.new(users(:compliance), proposal("compliance")).may_decide?
    assert_not ProposalPolicy.new(users(:owner), proposal("compliance")).may_decide?
    assert_not ProposalPolicy.new(users(:delegate), proposal("compliance")).may_decide?
  end
end
