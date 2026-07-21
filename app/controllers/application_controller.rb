class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  include AuditContext

  # Internal inventory: everyone authenticated reads everything. Auth surfaces
  # (login, OIDC callback, dev sign-in) skip this.
  before_action :require_login!

  helper_method :current_user, :signed_in?, :demo_mode?

  private

  def require_login!
    redirect_to login_path unless signed_in?
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = resolve_current_user
  end

  def signed_in?
    current_user.present?
  end

  def demo_mode?
    Demo.enabled?
  end

  def sign_in(user)
    cookies.signed[:session] = {
      value: { "user_id" => user.id },
      expires: 24.hours.from_now,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
    @current_user = user
  end

  def sign_out
    cookies.delete(:session)
    @current_user = nil
  end

  # The session cookie is a 24h bearer token. Authorization is computed live
  # from the DB every request, so deactivating a user (sync sets active: false)
  # kills their session on the next request — no session_version machinery
  # needed at compliventory's threat model.
  def resolve_current_user
    payload = cookies.signed[:session]
    return nil unless payload.is_a?(Hash)
    user = User.find_by(id: payload["user_id"])
    user if user&.active?
  end
end
