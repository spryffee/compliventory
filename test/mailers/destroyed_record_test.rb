require "test_helper"

# The two mailers handed a live record are enqueued for rows the app destroys by
# design: deciding a proposal destroys it, rejecting a pending asset destroys the
# asset. Delivery must not fail when the row is gone by the time the job runs.
class DestroyedRecordTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  test "a proposal decided before delivery does not fail the job" do
    proposal = ChangeProposal.create!(
      asset: vendors(:acme), proposer: users(:employee), lane: "owner",
      attribute_changes: { "description" => [ "Object storage and CDN.", "New" ] }, justification: "why not"
    )
    ProposalMailer.with(proposal: proposal, recipient: users(:owner)).created.deliver_later
    proposal.destroy!

    assert_no_emails { perform_enqueued_jobs }
  end

  test "a pending asset rejected before delivery does not fail the job" do
    vendor = vendors(:pending_vendor)
    AssetMailer.with(recipient: users(:compliance), asset: vendor, submitter: users(:employee))
               .submitted.deliver_later
    vendor.destroy!

    assert_no_emails { perform_enqueued_jobs }
  end
end
