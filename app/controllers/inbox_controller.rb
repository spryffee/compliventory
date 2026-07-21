# Owner-lane proposals awaiting me: changes proposed by others to assets I own
# or am delegated on.
class InboxController < ApplicationController
  def show
    @proposals = ChangeProposal.for_owner_inbox(current_user)
                               .includes(:proposer, :asset).oldest_first
  end
end
