# The compliance inbox: pending submissions (real rows in pending_approval),
# compliance-lane field proposals, and the vendor risk-assessment queue
# (in-progress, overdue, and never-assessed vendors).
class ComplianceController < ApplicationController
  before_action :require_compliance!

  def show
    @pending_vendors = Vendor.pending_approval.includes(:owner).order(:created_at)
    @pending_systems = System.pending_approval.includes(:owner).order(:created_at)
    @proposals = ChangeProposal.compliance_lane.includes(:proposer, :asset).oldest_first

    @in_progress_assessments = Assessment.in_progress.includes(:asset, :assessor).order(:created_at)
    reviewable = Vendor.not_under_assessment
    @overdue_vendors = reviewable.review_overdue.order(:next_review_on)
    @never_assessed_vendors = reviewable.never_assessed.order(:name)
  end

  private

  def require_compliance!
    render "shared/forbidden", status: :forbidden unless current_user.compliance?
  end
end
