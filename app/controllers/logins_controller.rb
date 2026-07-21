class LoginsController < ApplicationController
  skip_before_action :require_login!

  def show
    return redirect_to root_path if signed_in?
    # In the public demo there is no IdP — the persona picker is the front door.
    return redirect_to demo_sign_in_path if Demo.enabled?

    @oidc_configured = ENV["OIDC_ISSUER"].present?
  end
end
