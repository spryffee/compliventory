class OmniauthSessionsController < ApplicationController
  skip_before_action :require_login!

  # Email matching against the trusted corporate IdP (deliberate divergence from
  # governauthzer's STRICT subject pre-linking — see DESIGN.md). No JIT creation:
  # an unknown or inactive email gets the friendly "ask your admin" page.
  def callback
    auth = request.env["omniauth.auth"]
    if auth.nil?
      Rails.logger.warn("[oidc] callback hit without omniauth.auth")
      redirect_to login_path, alert: "Sign-in failed." and return
    end

    @email = auth.dig("info", "email").to_s.strip.downcase
    if @email.blank?
      Rails.logger.warn("[oidc] callback without an email claim (sub=#{auth['uid']})")
      redirect_to login_path, alert: "Sign-in failed: the identity provider returned no email." and return
    end

    user = User.find_by(email: @email)

    if user.nil? || !user.active?
      Rails.logger.warn("[oidc] no active user for email=#{@email}")
      render :unregistered, status: :forbidden and return
    end

    ActiveRecord::Base.transaction do
      sign_in(user)
      AuditEvent.record!(
        event_type: "auth.login",
        actor: user,
        targets: user,
        metadata: { "source" => "oidc" }
      )
    end

    redirect_to root_path, notice: "Signed in as #{user.name}."
  end

  def failure
    message = params[:message].to_s
    Rails.logger.warn("[oidc] auth failure: #{message} strategy=#{params[:strategy]}")
    redirect_to login_path, alert: "Sign-in failed: #{message.presence || 'unknown error'}"
  end
end
