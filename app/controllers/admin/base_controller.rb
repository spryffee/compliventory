class Admin::BaseController < ApplicationController
  before_action :require_admin!

  private

  def require_admin!
    return if current_user&.admin?
    render "admin/forbidden", status: :forbidden
  end

  # Shared audit emission for admin-UI mutations. `snapshot` captures a
  # destroyed record's identity before the row is gone (emit-before-destroy).
  def record_admin_audit(event_type, target, attribute_changes: nil, snapshot: nil)
    metadata = { "source" => "admin-ui" }
    metadata["snapshot"] = snapshot if snapshot
    AuditEvent.record!(
      event_type: event_type,
      actor: current_user,
      targets: target,
      attribute_changes: attribute_changes,
      metadata: metadata
    )
  end
end
