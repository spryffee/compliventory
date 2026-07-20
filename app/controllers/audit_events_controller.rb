# The global audit viewer (/audit) — compliance + admin. Per-asset trails on
# the detail pages are visible to everyone (transparency is the point).
class AuditEventsController < ApplicationController
  include Pagy::Method

  before_action :require_audit_access!

  def index
    scope = AuditEvent.recent_first
    scope = scope.where(event_type: params[:event_type]) if params[:event_type].present?
    scope = scope.where(actor_id: params[:actor_id]) if params[:actor_id].present?

    @pagy, @audit_events = pagy(:offset, scope, limit: 25)
    @event_types = AuditEvent.distinct.pluck(:event_type).sort
    @actors = User.order(:name)
  end

  private

  def require_audit_access!
    return if current_user.compliance? || current_user.admin?
    render "shared/forbidden", status: :forbidden
  end
end
