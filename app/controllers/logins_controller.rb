class LoginsController < ApplicationController
  skip_before_action :require_login!

  def show
    redirect_to root_path if signed_in?
    @oidc_configured = ENV["OIDC_ISSUER"].present?
  end
end
