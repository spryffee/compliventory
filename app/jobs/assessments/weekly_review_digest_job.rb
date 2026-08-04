module Assessments
  # Weekly reminder to the compliance team of vendors needing a risk review:
  # overdue reviews and never-assessed active vendors. A vendor whose assessment
  # is already in progress is left out of BOTH lists — the digest is a nag to
  # start work, and someone is already on it. One email per active compliance
  # user; the whole job is a no-op when there's nothing to review. Scheduled in
  # config/recurring.yml.
  class WeeklyReviewDigestJob < ApplicationJob
    def perform
      reviewable = Vendor.not_under_assessment

      overdue = reviewable.review_overdue.order(:next_review_on).to_a
      never_assessed = reviewable.never_assessed.order(:name).to_a

      return if overdue.empty? && never_assessed.empty?

      User.active.where(role: "compliance").find_each do |user|
        AssessmentMailer.with(recipient: user, overdue: overdue, never_assessed: never_assessed)
                        .weekly_digest.deliver_later
      end
    end
  end
end
