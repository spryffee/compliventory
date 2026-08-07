require "application_system_test_case"

# The end-to-end paths the suite otherwise only checks a layer at a time. Four
# tests, chosen because each one crosses a boundary the unit tests cannot: the
# browser, two actors in sequence, and the JavaScript.
class InventoryFlowsTest < ApplicationSystemTestCase
  test "signing in loads a working page, JavaScript and all" do
    sign_in_as users(:compliance)
    assert_text "Dashboard"

    click_on "Vendors"
    assert_selector "table"

    # The column picker is the app's only interactive JavaScript; if the
    # importmap or the CSP breaks, this is what stops working.
    within("[data-controller~='menu']", text: "Columns") do
      assert_no_selector "[data-menu-target='panel']", visible: true
      click_on "Columns"
      assert_selector "[data-menu-target='panel']", visible: true
    end
  end

  test "a member's submission becomes inventory once compliance approves it" do
    sign_in_as users(:employee)
    visit new_vendor_path
    fill_in "Name", with: "Zephyr Analytics"
    click_on "Submit vendor"

    assert_text "Submitted for compliance approval"
    assert_predicate Vendor.find_by(name: "Zephyr Analytics"), :pending_approval?

    sign_in_as users(:compliance)
    visit compliance_path
    # Scoped by action: the fixtures leave another submission in the queue, and
    # a submit button carries its label in an attribute, not as text.
    within("form[action='#{approve_vendor_path(Vendor.find_by(name: "Zephyr Analytics"))}']") do
      click_on "Approve"
    end

    assert_text "Zephyr Analytics approved"
    assert_equal "active", Vendor.find_by(name: "Zephyr Analytics").status
  end

  test "a non-owner's edit waits in the owner's inbox" do
    sign_in_as users(:employee)
    visit edit_vendor_path(vendors(:acme))
    fill_in "Description", with: "Object storage, CDN and queues."
    fill_in "justification", with: "Spotted on their pricing page."
    click_on "Save changes"

    assert_text "sent to the owner for review"
    assert_equal "Object storage and CDN.", vendors(:acme).reload.description

    sign_in_as users(:owner)
    visit inbox_path
    assert_text "Spotted on their pricing page."
    click_on "Approve"

    # Wait for the page before asking the database: Capybara synchronizes on the
    # browser, an assert_equal on a model does not.
    assert_text "Proposal approved"
    assert_equal "Object storage, CDN and queues.", vendors(:acme).reload.description
  end

  test "compliance runs a risk assessment to completion" do
    sign_in_as users(:compliance)
    visit vendor_path(vendors(:acme))
    click_on "Start assessment"

    # Asserting on structure, not the section headings: Tailwind renders those
    # uppercase, so their text does not match what the view says. The completion
    # fields are plain *_tag helpers, so they are named without a model prefix.
    assert_selector "select[name='residual_risk']"
    select "Low", from: "residual_risk"
    # exact, or it also matches "Approved with conditions".
    select "Approved", from: "decision", exact: true
    click_on "Complete assessment"

    assert_text "Assessment completed"
    assessment = vendors(:acme).assessments.sole
    assert_predicate assessment, :completed?
    assert_equal "low", vendors(:acme).reload.risk_tier
  end
end
