require "test_helper"

class AuditViewerTest < ActionDispatch::IntegrationTest
  test "members get no access" do
    sign_in_as users(:employee)
    get audit_events_path
    assert_response :forbidden
  end

  test "compliance and admin see the log" do
    sign_in_as users(:owner)
    patch vendor_path(vendors(:acme)), params: { vendor: { description: "for the log" } }
    delete logout_path

    [ users(:compliance), users(:admin) ].each do |viewer|
      sign_in_as viewer
      get audit_events_path
      assert_response :success
      assert_includes response.body, "vendor.updated"
      assert_includes response.body, "for the log"
      delete logout_path
    end
  end

  test "filters narrow by event type and actor" do
    sign_in_as users(:owner)
    patch vendor_path(vendors(:acme)), params: { vendor: { description: "owner change" } }
    delete logout_path

    sign_in_as users(:compliance)
    patch system_path(systems(:tracker)), params: { system: { criticality: "low" } }

    # Event names also appear as filter <option>s, so assert on row contents
    # (the rendered attribute diffs), not on the event names themselves.
    get audit_events_path(event_type: "vendor.updated")
    assert_includes response.body, "owner change"
    assert_not_includes response.body, "Criticality"

    get audit_events_path(actor_id: users(:owner).id)
    assert_includes response.body, "owner change"
    assert_not_includes response.body, "Criticality"
  end
end
