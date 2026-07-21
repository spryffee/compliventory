module Demo
  # Public-demo one-click sign-in over the shared seed personas — the demo's
  # answer to "how does a random visitor get in" without an IdP. Mirrors
  # Dev::SessionsController but gated on Demo.enabled? (DEMO_MODE) instead of
  # the development environment, so it is live in the deployed demo and 404s
  # everywhere else.
  class SessionsController < ApplicationController
    skip_before_action :require_login!
    before_action :ensure_demo!

    # Personas in role order (admin, compliance, then members) so the picker
    # reads top-down by capability.
    def new
      role_order = Arel.sql("array_position(ARRAY['admin','compliance','member']::varchar[], role)")
      @users = User.active.order(role_order).order(:name)
    end

    def create
      user = User.active.find_by(email: params[:email])
      return redirect_to(demo_sign_in_path, alert: "Unknown demo persona.") unless user

      ActiveRecord::Base.transaction do
        sign_in(user)
        AuditEvent.record!(
          event_type: "auth.demo_login",
          actor: user,
          targets: user,
          metadata: { "source" => "demo-sign-in" }
        )
      end
      redirect_to root_path, notice: "You're exploring as #{user.name} (#{user.role})."
    end

    private

    def ensure_demo!
      head :not_found unless Demo.enabled?
    end
  end
end
