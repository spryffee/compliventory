# Read-only user list + role picker. No create/delete — users arrive via the
# sync API (seed is the only carve-out); activation is sync-owned too.
class Admin::UsersController < Admin::BaseController
  def index
    @users = User.order(:name)
    @users = @users.where(role: params[:role]) if User::ROLES.include?(params[:role])
    @role = params[:role]
  end

  def update
    user = User.find(params[:id])
    new_role = params.dig(:user, :role)
    unless User::ROLES.include?(new_role)
      return redirect_to admin_users_path, alert: "Unknown role."
    end

    if user.role != new_role
      changes = { "role" => [ user.role, new_role ] }
      ActiveRecord::Base.transaction do
        user.update!(role: new_role)
        record_admin_audit("user.role_changed", user, attribute_changes: changes)
      end
    end
    redirect_to admin_users_path, notice: "#{user.name} is now #{new_role}."
  end
end
