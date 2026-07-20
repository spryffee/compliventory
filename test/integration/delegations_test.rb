require "test_helper"

class DelegationsTest < ActionDispatch::IntegrationTest
  test "the owner adds and removes a delegate, audited" do
    sign_in_as users(:owner)

    assert_difference([ "Delegation.count", "AuditEvent.where(event_type: 'delegation.added').count" ], 1) do
      post vendor_delegations_path(vendors(:acme)), params: { delegation: { user_id: users(:employee).id } }
    end
    assert_redirected_to vendor_path(vendors(:acme))

    event = AuditEvent.where(event_type: "delegation.added").recent_first.first
    assert_equal vendors(:acme).id, event.target_id("Vendor")
    assert_equal users(:employee).id, event.target_id("User")

    delegation = vendors(:acme).delegations.find_by!(user: users(:employee))
    assert_difference("AuditEvent.where(event_type: 'delegation.removed').count", 1) do
      delete vendor_delegation_path(vendors(:acme), delegation)
    end
    assert_not Delegation.exists?(delegation.id)
  end

  test "a delegate manages delegates too" do
    sign_in_as users(:delegate)
    post system_delegations_path(systems(:tracker)), params: { delegation: { user_id: users(:employee).id } }
    assert systems(:tracker).owned_or_delegated_to?(users(:employee))
  end

  test "an unrelated member may not manage delegates" do
    sign_in_as users(:employee)
    assert_no_difference("Delegation.count") do
      post vendor_delegations_path(vendors(:acme)), params: { delegation: { user_id: users(:employee).id } }
    end
    assert_response :forbidden
  end

  test "an inactive user cannot be added as delegate" do
    sign_in_as users(:owner)
    assert_no_difference("Delegation.count") do
      post vendor_delegations_path(vendors(:acme)), params: { delegation: { user_id: users(:inactive).id } }
    end
    assert_redirected_to vendor_path(vendors(:acme))
    assert_match "Could not add", flash[:alert]
  end

  test "adding the same delegate twice fails gracefully" do
    sign_in_as users(:owner)
    assert_no_difference("Delegation.count") do
      post vendor_delegations_path(vendors(:acme)), params: { delegation: { user_id: users(:delegate).id } }
    end
    assert_match "Could not add", flash[:alert]
  end
end
