# The compliance inbox: pending submissions (real rows in pending_approval)
# plus compliance-lane field proposals.
class ComplianceController < ApplicationController
  before_action :require_compliance!

  def show
    @pending_vendors = Vendor.pending_approval.includes(:owner).order(:created_at)
    @pending_systems = System.pending_approval.includes(:owner).order(:created_at)
    @proposals = ChangeProposal.compliance_lane.includes(:proposer, :asset).oldest_first
  end

  private

  def require_compliance!
    render "shared/forbidden", status: :forbidden unless current_user.compliance?
  end
end
