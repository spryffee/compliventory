require "test_helper"

class ChangeProposalTest < ActiveSupport::TestCase
  setup do
    @proposal = ChangeProposal.create!(
      asset: vendors(:acme), proposer: users(:employee), lane: "owner",
      attribute_changes: { "description" => [ "Object storage and CDN.", "New" ] }
    )
  end

  test "requires a known lane and non-empty changes" do
    assert_not ChangeProposal.new(asset: vendors(:acme), proposer: users(:employee), lane: "boss", attribute_changes: { "a" => [ 1, 2 ] }).valid?
    assert_not ChangeProposal.new(asset: vendors(:acme), proposer: users(:employee), lane: "owner", attribute_changes: {}).valid?
  end

  test "for_owner_inbox covers owned and delegated assets only" do
    system_proposal = ChangeProposal.create!(
      asset: systems(:wiki), proposer: users(:owner), lane: "owner",
      attribute_changes: { "description" => [ nil, "docs" ] }
    )

    assert_includes ChangeProposal.for_owner_inbox(users(:owner)), @proposal
    assert_includes ChangeProposal.for_owner_inbox(users(:delegate)), @proposal
    assert_not_includes ChangeProposal.for_owner_inbox(users(:owner)), system_proposal
    assert_includes ChangeProposal.for_owner_inbox(users(:employee)), system_proposal # owns wiki
  end

  test "compliance-lane proposals never appear in the owner inbox" do
    compliance_proposal = ChangeProposal.create!(
      asset: vendors(:acme), proposer: users(:employee), lane: "compliance",
      attribute_changes: { "data_location" => [ "eu", "us" ] }
    )
    assert_not_includes ChangeProposal.for_owner_inbox(users(:owner)), compliance_proposal
  end

  test "stale? compares the base against the current value" do
    assert_not @proposal.stale?("description")
    vendors(:acme).update!(description: "Changed meanwhile")
    assert @proposal.reload.stale?("description")
    assert_equal "Changed meanwhile", @proposal.current_value("description")
    assert_equal "Object storage and CDN.", @proposal.base_value("description")
  end

  test "reviewers: owner lane is owner+delegates, compliance lane is the compliance team, minus proposer" do
    assert_equal [ users(:owner), users(:delegate) ].to_set, @proposal.reviewers.to_set

    compliance_proposal = ChangeProposal.new(asset: vendors(:acme), proposer: users(:owner), lane: "compliance",
                                             attribute_changes: { "data_location" => [ "eu", "us" ] })
    assert_equal [ users(:compliance) ], compliance_proposal.reviewers

    own = ChangeProposal.new(asset: vendors(:acme), proposer: users(:owner), lane: "owner",
                             attribute_changes: { "notes" => [ nil, "x" ] })
    assert_equal [ users(:delegate) ], own.reviewers
  end
end
