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
    in_progress_vendor_ids = @in_progress_assessments.select { |a| a.asset_type == "Vendor" }.map(&:asset_id)
    @overdue_vendors = Vendor.active.where(next_review_on: ..Date.current).order(:next_review_on)
    @never_assessed_vendors = Vendor.active.where(last_assessed_on: nil)
                                    .where.not(id: in_progress_vendor_ids).order(:name)
  end

  private

  def require_compliance!
    render "shared/forbidden", status: :forbidden unless current_user.compliance?
  end
end
