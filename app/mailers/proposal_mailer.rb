class ProposalMailer < ApplicationMailer
  # A new proposal awaits the recipient's review.
  def created
    @proposal = params[:proposal]
    @asset = @proposal.asset
    mail to: params[:recipient].email,
         subject: "[compliventory] Change proposal for #{@asset.name}"
  end

  # The recipient's proposal was decided. The proposal row is gone by the time
  # this renders, so everything arrives as plain values.
  def decided
    @decision = params[:decision]
    @decided_by = params[:decided_by]
    @asset_type = params[:asset_type]
    @asset_id = params[:asset_id]
    @asset_name = params[:asset_name]
    @changes = params[:changes]
    @comment = params[:comment]
    mail to: params[:recipient].email,
         subject: "[compliventory] Your proposal for #{@asset_name} was #{@decision}"
  end
end
