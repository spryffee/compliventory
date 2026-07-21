class AssetMailer < ApplicationMailer
  # A new submission awaits compliance review.
  def submitted
    @asset = params[:asset]
    @submitter = params[:submitter]
    mail to: params[:recipient].email,
         subject: "[compliventory] New #{@asset.model_name.human.downcase} submitted: #{@asset.name}"
  end

  # The recipient's submission was decided. On reject the row is gone, so
  # everything arrives as plain values.
  def decided
    @decision = params[:decision]
    @decided_by = params[:decided_by]
    @asset_type = params[:asset_type]
    @asset_id = params[:asset_id]
    @asset_name = params[:asset_name]
    @comment = params[:comment]
    mail to: params[:recipient].email,
         subject: "[compliventory] #{@asset_name} was #{@decision}"
  end
end
