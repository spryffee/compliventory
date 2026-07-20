require "test_helper"

class SystemsTest < ActionDispatch::IntegrationTest
  test "list and detail render for any member" do
    sign_in_as users(:employee)

    get systems_path
    assert_response :success
    assert_includes response.body, "Issue Tracker"
    assert_includes response.body, "In-house" # wiki has no vendor

    get system_path(systems(:tracker))
    assert_response :success
    assert_includes response.body, "Acme Cloud"
    assert_includes response.body, "Data classification"
  end

  test "a member submits a system with personal data categories" do
    sign_in_as users(:employee)

    post systems_path, params: { system: {
      name: "Payroll", owner_id: users(:owner).id, vendor_id: vendors(:acme).id,
      stores_personal_data: "true", personal_data_categories: [ "", "employees" ]
    } }
    system = System.find_by!(name: "Payroll")
    assert_redirected_to system_path(system)
    assert_equal "pending_approval", system.status
    assert_equal %w[employees], system.personal_data_categories
  end

  test "the owner cannot flip a pending system to active" do
    sign_in_as users(:employee) # owner of the pending submission below
    post systems_path, params: { system: { name: "Shadow IT", owner_id: users(:employee).id } }
    system = System.find_by!(name: "Shadow IT")

    patch system_path(system), params: { system: { status: "active" } }
    assert_equal "pending_approval", system.reload.status
  end

  test "compliance edits ⚖ fields directly, audited" do
    sign_in_as users(:compliance)

    assert_difference("AuditEvent.where(event_type: 'system.updated').count", 1) do
      patch system_path(systems(:tracker)), params: { system: { criticality: "critical", personal_data_categories: [ "employees", "customers" ] } }
    end
    systems(:tracker).reload
    assert_equal "critical", systems(:tracker).criticality
    assert_equal %w[employees customers], systems(:tracker).personal_data_categories
  end

  test "admin repairs ownership but nothing else" do
    sign_in_as users(:admin)

    patch system_path(systems(:tracker)), params: { system: { owner_id: users(:employee).id } }
    assert_equal users(:employee).id, systems(:tracker).reload.owner_id

    patch system_path(systems(:tracker)), params: { system: { name: "Renamed by admin" } }
    assert_equal "Issue Tracker", systems(:tracker).reload.name
  end
end
