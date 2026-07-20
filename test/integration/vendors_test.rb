require "test_helper"

class VendorsTest < ActionDispatch::IntegrationTest
  test "anyone signed in reads the list and detail page" do
    sign_in_as users(:employee)

    get vendors_path
    assert_response :success
    assert_includes response.body, "Acme Cloud"

    get vendor_path(vendors(:acme))
    assert_response :success
    assert_includes response.body, "Oscar Owner"
    assert_includes response.body, "Risk tier"
  end

  test "signed-out users are redirected to login" do
    get vendors_path
    assert_redirected_to login_path
  end

  test "a member submits a vendor, it lands pending" do
    sign_in_as users(:employee)

    assert_difference("Vendor.count", 1) do
      post vendors_path, params: { vendor: { name: "FreshSaaS", category: "saas", owner_id: users(:employee).id } }
    end
    vendor = Vendor.find_by!(name: "FreshSaaS")
    assert_redirected_to vendor_path(vendor)
    assert_equal "pending_approval", vendor.status
  end

  test "a member's submitted risk_tier is ignored" do
    sign_in_as users(:employee)
    post vendors_path, params: { vendor: { name: "Sneaky Inc", owner_id: users(:employee).id, risk_tier: "low" } }
    assert_nil Vendor.find_by!(name: "Sneaky Inc").risk_tier
  end

  test "a compliance submission goes straight to active" do
    sign_in_as users(:compliance)
    post vendors_path, params: { vendor: { name: "Assessed Inc", owner_id: users(:owner).id, risk_tier: "high" } }
    vendor = Vendor.find_by!(name: "Assessed Inc")
    assert_equal "active", vendor.status
    assert_equal "high", vendor.risk_tier
  end

  test "invalid submission re-renders the form" do
    sign_in_as users(:employee)
    assert_no_difference("Vendor.count") do
      post vendors_path, params: { vendor: { name: "", owner_id: users(:employee).id } }
    end
    assert_response :unprocessable_content
    assert_includes response.body, "Could not save"
  end

  test "the owner edits regular fields, audited" do
    sign_in_as users(:owner)

    get edit_vendor_path(vendors(:acme))
    assert_response :success
    # ⚖ compliance-only field is not even rendered for the owner
    assert_no_match(/vendor\[risk_tier\]/, response.body)

    assert_difference("AuditEvent.where(event_type: 'vendor.updated').count", 1) do
      patch vendor_path(vendors(:acme)), params: { vendor: { description: "Updated by owner" } }
    end
    assert_redirected_to vendor_path(vendors(:acme))
    assert_equal "Updated by owner", vendors(:acme).reload.description
  end

  test "a delegate edits like the owner" do
    sign_in_as users(:delegate)
    patch vendor_path(vendors(:acme)), params: { vendor: { notes: "delegate was here" } }
    assert_redirected_to vendor_path(vendors(:acme))
    assert_equal "delegate was here", vendors(:acme).reload.notes
  end

  test "risk_tier sent by the owner is filtered out, not applied" do
    sign_in_as users(:owner)
    patch vendor_path(vendors(:acme)), params: { vendor: { risk_tier: "low", description: "combo" } }
    vendors(:acme).reload
    assert_equal "medium", vendors(:acme).risk_tier
    assert_equal "combo", vendors(:acme).description
  end

  test "an unrelated member gets no edit access" do
    sign_in_as users(:employee)

    get edit_vendor_path(vendors(:acme))
    assert_response :forbidden

    patch vendor_path(vendors(:acme)), params: { vendor: { name: "Evil Corp" } }
    assert_response :forbidden
    assert_equal "Acme Cloud", vendors(:acme).reload.name
  end

  test "compliance edits compliance fields and activates a pending vendor" do
    sign_in_as users(:compliance)
    patch vendor_path(vendors(:pending_vendor)), params: { vendor: { status: "active", risk_tier: "low" } }
    vendors(:pending_vendor).reload
    assert_equal "active", vendors(:pending_vendor).status
    assert_equal "low", vendors(:pending_vendor).risk_tier
  end

  test "detail page shows the audit trail" do
    sign_in_as users(:owner)
    patch vendor_path(vendors(:acme)), params: { vendor: { description: "traceable" } }

    get vendor_path(vendors(:acme))
    assert_includes response.body, "vendor.updated"
    assert_includes response.body, "traceable"
  end
end
