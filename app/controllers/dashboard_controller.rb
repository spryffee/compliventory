# The landing page (DESIGN.md, "UI map"): my assets, my pending approvals,
# recent activity on my assets. Compliance users also see their queue size.
class DashboardController < ApplicationController
  def index
    @my_vendors = my_assets(Vendor)
    @my_systems = my_assets(System)
    @inbox_proposals = ChangeProposal.for_owner_inbox(current_user)
                                     .includes(:proposer, :asset).oldest_first
    if current_user.compliance?
      @pending_submissions = Vendor.pending_approval.count + System.pending_approval.count
      @compliance_proposals = ChangeProposal.compliance_lane.count
    end
    @recent_events = recent_events
  end

  private

  def my_assets(klass)
    klass.where(owner_id: current_user.id)
         .or(klass.where(id: Delegation.where(user: current_user, asset_type: klass.name).select(:asset_id)))
         .order(:name)
  end

  # Activity touching assets I own or co-manage, newest first.
  def recent_events
    assets = @my_vendors + @my_systems
    return AuditEvent.none if assets.empty?
    assets.map { |asset| AuditEvent.for_target(asset) }.reduce(:or).recent_first.limit(8)
  end
end
