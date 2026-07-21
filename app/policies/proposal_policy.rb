# Who may approve/reject a pending change proposal. Compliance may decide both
# lanes (they can apply any change directly anyway); the owner lane is decided
# by the asset's owner or a delegate.
class ProposalPolicy
  def initialize(user, proposal)
    @user = user
    @proposal = proposal
  end

  def may_decide?
    return true if @user.compliance?

    @proposal.lane == "owner" && @proposal.asset.owned_or_delegated_to?(@user)
  end
end
