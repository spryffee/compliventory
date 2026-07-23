require "test_helper"

class AssessmentSurfacingTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    # acme fixture is active with no assessment dates → "never assessed".
    @overdue  = Vendor.create!(name: "Overdue Co", owner: @owner, status: "active",
                               last_assessed_on: 2.years.ago, next_review_on: 1.day.ago)
    @due_soon = Vendor.create!(name: "DueSoon Co", owner: @owner, status: "active",
                               last_assessed_on: 1.year.ago, next_review_on: 10.days.from_now)
    @ok       = Vendor.create!(name: "UpToDate Co", owner: @owner, status: "active",
                               last_assessed_on: 1.month.ago, next_review_on: 6.months.from_now)
  end

  # --- Vendors table: review-status filter ---------------------------------

  test "the review-status filter partitions vendors by their review dates" do
    sign_in_as users(:employee)

    get vendors_path(review_status: "overdue")
    assert_includes response.body, "Overdue Co"
    assert_not_includes response.body, "UpToDate Co"
    assert_not_includes response.body, "Acme Cloud"

    get vendors_path(review_status: "due_soon")
    assert_includes response.body, "DueSoon Co"
    assert_not_includes response.body, "Overdue Co"

    get vendors_path(review_status: "never")
    assert_includes response.body, "Acme Cloud"
    assert_not_includes response.body, "Overdue Co"

    get vendors_path(review_status: "ok")
    assert_includes response.body, "UpToDate Co"
    assert_not_includes response.body, "Overdue Co"
    assert_not_includes response.body, "DueSoon Co"
  end

  test "the next-review column is selectable and flags overdue dates" do
    user = users(:employee)
    sign_in_as user
    patch table_preference_path("vendors"), params: { columns: %w[next_review_on] }

    get vendors_path
    assert_includes response.body, "sort=next_review_on"
    assert_includes response.body, "overdue" # Overdue Co's next_review_on is in the past
  end

  # --- /compliance assessments section -------------------------------------

  test "the compliance inbox lists in-progress, overdue and never-assessed vendors" do
    Current.correlation_id = SecureRandom.uuid
    Assessments::Starter.call(vendor: @due_soon, actor: users(:compliance))
    Current.reset

    sign_in_as users(:compliance)
    get compliance_path

    assert_includes response.body, "Risk assessments"
    assert_includes response.body, "In progress"
    assert_includes response.body, "DueSoon Co"    # in progress
    assert_includes response.body, "Overdue Co"    # overdue
    assert_includes response.body, "Never assessed"
    assert_includes response.body, "Acme Cloud"    # never assessed
  end

  test "a vendor being assessed is not also listed as never-assessed" do
    Current.correlation_id = SecureRandom.uuid
    Assessments::Starter.call(vendor: vendors(:acme), actor: users(:compliance))
    Current.reset

    sign_in_as users(:compliance)
    get compliance_path

    # acme now appears once (in progress), not in the never-assessed list.
    assert_equal 1, response.body.scan("Acme Cloud").size
  end
end
