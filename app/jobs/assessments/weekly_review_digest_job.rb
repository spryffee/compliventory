module Assessments
  # Weekly reminder to the compliance team of vendors needing a risk review:
  # overdue reviews and never-assessed active vendors (a vendor currently being
  # assessed is not counted). One email per active compliance user; the whole
  # job is a no-op when there's nothing to review. Scheduled in config/recurring.yml.
  class WeeklyReviewDigestJob < ApplicationJob
    def perform
      overdue = Vendor.active.where(next_review_on: ..Date.current).order(:next_review_on).to_a

      in_progress_vendor_ids = Assessment.in_progress.where(asset_type: "Vendor").pluck(:asset_id)
      never_assessed = Vendor.active.where(last_assessed_on: nil)
                             .where.not(id: in_progress_vendor_ids).order(:name).to_a

      return if overdue.empty? && never_assessed.empty?

      User.active.where(role: "compliance").find_each do |user|
        AssessmentMailer.with(recipient: user, overdue: overdue, never_assessed: never_assessed)
                        .weekly_digest.deliver_later
      end
    end
  end
end
