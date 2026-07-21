# Approve/reject decisions on change proposals. Reached from /inbox,
# /compliance and the asset detail pages — redirects go back where the
# reviewer came from.
class ProposalsController < ApplicationController
  def approve
    proposal = ChangeProposal.find(params[:id])
    asset = proposal.asset
    result = Proposals::Approver.call(proposal: proposal, actor: current_user, comment: params[:comment])

    if result.success
      redirect_back fallback_location: asset, notice: "Proposal approved — changes applied."
    elsif result.code == :validation_failed
      errors = result.context[:record].errors.full_messages.join(", ")
      redirect_back fallback_location: asset, alert: "Could not apply the proposal: #{errors}."
    else
      render "shared/forbidden", status: :forbidden
    end
  end

  def reject
    proposal = ChangeProposal.find(params[:id])
    asset = proposal.asset
    result = Proposals::Rejecter.call(proposal: proposal, actor: current_user, comment: params[:comment])

    if result.success
      redirect_back fallback_location: asset, notice: "Proposal rejected."
    else
      render "shared/forbidden", status: :forbidden
    end
  end
end
