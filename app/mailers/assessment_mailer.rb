class AssessmentMailer < ApplicationMailer
  # A vendor risk assessment was completed — the vendor owner learns the outcome.
  # The completed record is permanent, so the assessment is passed as an object.
  def completed
    @assessment = params[:assessment]
    @vendor = @assessment.asset
    @assessor = params[:assessor]
    mail to: params[:recipient].email,
         subject: "[compliventory] Risk assessment completed for #{@vendor.name}"
  end

  # Weekly compliance digest of vendors that need a risk review (overdue reviews
  # and never-assessed active vendors). Enqueued per compliance user by
  # Assessments::WeeklyReviewDigestJob, which skips sending when both lists empty.
  def weekly_digest
    @overdue = params[:overdue]
    @never_assessed = params[:never_assessed]
    count = @overdue.size + @never_assessed.size
    mail to: params[:recipient].email,
         subject: "[compliventory] #{count} #{'vendor'.pluralize(count)} need a risk review"
  end
end
