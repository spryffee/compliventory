# Owner/delegate/compliance/admin manage an asset's delegates. Add/remove is
# audited with the asset AND the delegate as targets, so both audit trails
# carry the event.
class DelegationsController < ApplicationController
  ASSET_TYPES = { "Vendor" => Vendor, "System" => System }.freeze

  before_action :set_asset
  before_action :require_delegate_management!

  def create
    user = User.active.find(params.require(:delegation)[:user_id])
    delegation = @asset.delegations.new(user: user)

    ActiveRecord::Base.transaction do
      delegation.save!
      record_delegation_audit("delegation.added", user)
    end
    redirect_to @asset, notice: "#{user.name} added as delegate."
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    redirect_to @asset, alert: "Could not add that delegate."
  end

  def destroy
    delegation = @asset.delegations.find(params[:id])
    user = delegation.user

    ActiveRecord::Base.transaction do
      delegation.destroy!
      record_delegation_audit("delegation.removed", user)
    end
    redirect_to @asset, notice: "#{user.name} removed as delegate."
  end

  private

  def set_asset
    asset_class = ASSET_TYPES.fetch(params[:asset_type])
    @asset = asset_class.find(params[:vendor_id] || params[:system_id])
  end

  def require_delegate_management!
    policy = AssetPolicy.for(current_user, @asset)
    render "shared/forbidden", status: :forbidden unless policy.may_manage_delegates?
  end

  def record_delegation_audit(event_type, user)
    AuditEvent.record!(
      event_type: event_type,
      actor: current_user,
      targets: [ @asset, user ],
      metadata: { "source" => "web-ui" }
    )
  end
end
