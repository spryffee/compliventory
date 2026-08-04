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
    klass.owned_or_delegated_to(current_user).order(:name)
  end

  # Activity touching assets I own or co-manage, newest first.
  def recent_events
    AuditEvent.for_any_target(@my_vendors + @my_systems).recent_first.limit(8)
  end
end
