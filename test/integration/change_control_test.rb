require "test_helper"

class ChangeControlTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  # --- proposal creation through the edit form -----------------------------

  test "a non-owner edit becomes an owner-lane proposal with justification, reviewers notified" do
    sign_in_as users(:employee)

    assert_enqueued_emails 2 do # owner + delegate
      assert_difference("ChangeProposal.owner_lane.count", 1) do
        patch vendor_path(vendors(:acme)),
              params: { vendor: { description: "Suggested description" }, justification: "typo fix" }
      end
    end
    assert_equal "Object storage and CDN.", vendors(:acme).reload.description
    assert_equal "typo fix", ChangeProposal.owner_lane.sole.justification

    follow_redirect!
    assert_includes response.body, "sent to the owner for review"
  end

  test "an owner's mixed edit applies regular fields and proposes ⚖ fields" do
    sign_in_as users(:owner)

    assert_difference("ChangeProposal.compliance_lane.count", 1) do
      patch vendor_path(vendors(:acme)),
            params: { vendor: { notes: "fresh note", processes_personal_data: "false" } }
    end
    acme = vendors(:acme).reload
    assert_equal "fresh note", acme.notes
    assert_equal true, acme.processes_personal_data

    follow_redirect!
    assert_includes response.body, "Changes saved."
    assert_includes response.body, "sent to compliance for review"
  end

  test "pending proposals show on the asset detail page" do
    sign_in_as users(:employee)
    patch vendor_path(vendors(:acme)), params: { vendor: { description: "Visible proposal" } }

    get vendor_path(vendors(:acme))
    assert_includes response.body, "Pending changes"
    assert_includes response.body, "Visible proposal"
  end

  # --- owner inbox ---------------------------------------------------------

  test "owner sees the proposal in /inbox and approving applies it" do
    sign_in_as users(:employee)
    patch vendor_path(vendors(:acme)), params: { vendor: { description: "Approved later" } }
    delete logout_path

    sign_in_as users(:owner)
    get inbox_path
    assert_response :success
    assert_includes response.body, "Approved later"

    proposal = ChangeProposal.owner_lane.sole
    assert_enqueued_emails 1 do # proposer notified
      assert_difference("ChangeProposal.count", -1) do
        post approve_proposal_path(proposal), params: { comment: "ok" }
      end
    end
    assert_equal "Approved later", vendors(:acme).reload.description
    assert_equal 1, AuditEvent.where(event_type: "proposal.approved").count
  end

  test "a delegate rejects from the inbox" do
    sign_in_as users(:employee)
    patch system_path(systems(:tracker)), params: { system: { department: "Sales" } }
    delete logout_path

    sign_in_as users(:delegate)
    get inbox_path
    assert_includes response.body, "Sales"

    proposal = ChangeProposal.owner_lane.sole
    post reject_proposal_path(proposal), params: { comment: "wrong department" }
    assert_equal "Engineering", systems(:tracker).reload.department
    assert_not ChangeProposal.exists?(proposal.id)
    assert_equal 1, AuditEvent.where(event_type: "proposal.rejected").count
  end

  test "an unrelated member may not decide a proposal" do
    proposal = ChangeProposal.create!(
      asset: vendors(:acme), proposer: users(:owner), lane: "owner",
      attribute_changes: { "notes" => [ nil, "x" ] }
    )
    sign_in_as users(:employee)
    post approve_proposal_path(proposal)
    assert_response :forbidden
    assert ChangeProposal.exists?(proposal.id)
  end

  test "a stale proposal shows base, current and proposed values" do
    proposal = ChangeProposal.create!(
      asset: vendors(:acme), proposer: users(:employee), lane: "owner",
      attribute_changes: { "description" => [ "Object storage and CDN.", "Proposed text" ] }
    )
    vendors(:acme).update!(description: "Changed meanwhile")

    sign_in_as users(:owner)
    get inbox_path
    assert_includes response.body, "Proposed text"
    assert_includes response.body, "now Changed meanwhile"
    assert proposal.stale?("description")
  end

  # --- compliance inbox ----------------------------------------------------

  test "members and admins may not open /compliance" do
    sign_in_as users(:employee)
    get compliance_path
    assert_response :forbidden
    delete logout_path

    sign_in_as users(:admin)
    get compliance_path
    assert_response :forbidden
  end

  test "compliance approves a pending submission from /compliance" do
    sign_in_as users(:compliance)
    get compliance_path
    assert_response :success
    assert_includes response.body, "NewTool.io"

    assert_enqueued_emails 1 do # owner notified
      post approve_vendor_path(vendors(:pending_vendor)), params: { comment: "checked" }
    end
    assert_redirected_to compliance_path
    assert_equal "active", vendors(:pending_vendor).reload.status
    assert_equal 1, AuditEvent.where(event_type: "vendor.approved").count
  end

  test "compliance rejects a pending submission — row gone, snapshot audited" do
    sign_in_as users(:compliance)

    assert_difference("Vendor.count", -1) do
      post reject_vendor_path(vendors(:pending_vendor)), params: { comment: "duplicate" }
    end
    event = AuditEvent.where(event_type: "vendor.rejected").sole
    assert_equal "NewTool.io", event.metadata["snapshot"]["name"]
  end

  test "compliance-lane proposals are decided from /compliance" do
    sign_in_as users(:owner)
    patch system_path(systems(:tracker)), params: { system: { criticality: "critical" } }
    delete logout_path

    sign_in_as users(:compliance)
    get compliance_path
    assert_includes response.body, "Criticality"

    proposal = ChangeProposal.compliance_lane.sole
    post approve_proposal_path(proposal)
    assert_equal "critical", systems(:tracker).reload.criticality
  end

  test "non-compliance may not decide pending submissions" do
    sign_in_as users(:employee) # owns the pending vendor
    post approve_vendor_path(vendors(:pending_vendor))
    assert_response :forbidden
    assert_equal "pending_approval", vendors(:pending_vendor).reload.status
  end

  test "a member submission notifies the compliance team" do
    sign_in_as users(:employee)
    assert_enqueued_emails 1 do
      post vendors_path, params: { vendor: { name: "Mailed Inc", owner_id: users(:employee).id } }
    end
  end
end
