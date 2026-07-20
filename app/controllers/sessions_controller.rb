class SessionsController < ApplicationController
  skip_before_action :require_login!

  def destroy
    sign_out
    redirect_to login_path, status: :see_other, notice: "You've been signed out."
  end
end
