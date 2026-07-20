module Dev
  # Development-only one-click sign-in over seed data, so local testing doesn't
  # require an IdP. Hard-guarded twice: the routes are only declared under
  # `if Rails.env.development?` (so they 404 in prod), and this before_action is
  # a belt-and-suspenders second line. NEVER reachable outside development.
  class SessionsController < ApplicationController
    skip_before_action :require_login!
    before_action :ensure_development!

    def new
      @users = User.active.order(:name)
    end

    def create
      user = User.find_by(email: params[:email])
      unless user&.active?
        return redirect_to(dev_sign_in_path, alert: "No active user with that email.")
      end

      ActiveRecord::Base.transaction do
        sign_in(user)
        AuditEvent.record!(
          event_type: "auth.dev_login",
          actor: user,
          targets: user,
          metadata: { "source" => "dev-sign-in" }
        )
      end
      redirect_to root_path, notice: "Signed in as #{user.name} (dev)."
    end

    private

    def ensure_development!
      head :not_found unless Rails.env.development?
    end
  end
end
