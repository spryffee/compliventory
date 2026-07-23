require "test_helper"

module Assessments
  class WeeklyReviewDigestJobTest < ActiveJob::TestCase
    include ActionMailer::TestHelper

    test "emails each active compliance user when vendors need a review" do
      # acme (fixture) is active with no assessment dates → never assessed, so
      # there is always something to review here. One compliance user in fixtures.
      assert_enqueued_emails 1 do
        WeeklyReviewDigestJob.perform_now
      end
    end

    test "sends nothing when every active vendor is up to date" do
      Vendor.active.update_all(last_assessed_on: Date.current, next_review_on: Date.current + 1.year)

      assert_no_enqueued_emails do
        WeeklyReviewDigestJob.perform_now
      end
    end

    test "a vendor being assessed right now is not counted as never assessed" do
      Vendor.active.update_all(last_assessed_on: Date.current, next_review_on: Date.current + 1.year)
      fresh = Vendor.create!(name: "Fresh Co", owner: users(:owner), status: "active")
      Current.correlation_id = SecureRandom.uuid
      Starter.call(vendor: fresh, actor: users(:compliance))
      Current.reset

      assert_no_enqueued_emails do
        WeeklyReviewDigestJob.perform_now
      end
    end
  end
end
