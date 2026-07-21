require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "an owner sees their assets, pending proposals and recent activity" do
    ChangeProposal.create!(
      asset: vendors(:acme), proposer: users(:employee), lane: "owner",
      attribute_changes: { "description" => [ nil, "Better description" ] }
    )
    Current.correlation_id = SecureRandom.uuid
    AuditEvent.record!(event_type: "vendor.updated", actor: users(:owner), targets: [ vendors(:acme) ])

    sign_in_as users(:owner)
    get root_path
    assert_response :success

    assert_includes response.body, "1 proposed change waiting for your review"
    assert_includes response.body, "Acme Cloud"
    assert_includes response.body, "Issue Tracker"
    assert_includes response.body, "Recent activity on your assets"
    assert_includes response.body, "vendor.updated"
  end

  test "a delegate sees delegated assets marked" do
    sign_in_as users(:delegate)
    get root_path
    assert_response :success
    assert_includes response.body, "delegate</span>"
  end

  test "compliance sees their queue" do
    sign_in_as users(:compliance)
    get root_path
    assert_response :success
    assert_includes response.body, "Compliance queue"
    assert_includes response.body, "pending submission"
  end

  test "a member with nothing going on sees calm empty states" do
    sign_in_as users(:employee)
    get root_path
    assert_response :success
    assert_not_includes response.body, "Compliance queue"
    assert_not_includes response.body, "Recent activity"
  end
end
