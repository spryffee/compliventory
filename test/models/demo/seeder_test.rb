require "test_helper"

class Demo::SeederTest < ActiveSupport::TestCase
  test "reset! produces the canonical demo dataset" do
    Demo::Seeder.reset!

    assert_equal 6, User.count           # 5 active personas + inactive Gary
    assert_equal 5, User.active.count
    assert_equal 10, Vendor.count
    assert_equal 8, System.count
    assert_equal 2, Delegation.count
    assert_equal 1, ChangeProposal.count
    assert_equal %w[admin compliance member], User.active.distinct.pluck(:role).sort

    # Assessments in every state so /compliance and the table filters demo well.
    assert_equal 1, Assessment.in_progress.count
    assert_equal 2, Assessment.completed.count
    assert Vendor.find_by(name: "PeopleFirst HR").next_review_on.past?, "one vendor is overdue"
    assert Vendor.active.where(last_assessed_on: nil).exists?, "some vendors are never assessed"
  end

  test "reset! wipes visitor changes and minted tokens" do
    Demo::Seeder.reset!
    Vendor.create!(name: "Vandal Corp", owner: User.first)
    ApiToken.create!(name: "sneaky", token_digest: "x" * 64)

    Demo::Seeder.reset!

    assert_nil Vendor.find_by(name: "Vandal Corp")
    assert_equal 0, ApiToken.count
    assert_equal 10, Vendor.count
  end

  test "seed! is idempotent" do
    Demo::Seeder.reset!
    assert_no_difference [ "User.count", "Vendor.count", "System.count", "ChangeProposal.count", "Assessment.count" ] do
      Demo::Seeder.seed!
    end
  end
end
