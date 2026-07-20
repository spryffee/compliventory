class Api::V1::BaseController < ActionController::API
  include AuditContext
  include Api::ErrorRendering

  before_action :authenticate_api_token!

  # The authenticated consumer lives in Current (single source of truth) so audit
  # emission deep in services can attribute events without kwarg-threading.
  def current_api_token
    Current.api_token
  end

  private

  def require_scope!(required_scope)
    return if current_api_token.allows?(required_scope)

    render_error(
      code: "scope_insufficient",
      status: :forbidden,
      message: "This token does not carry the #{required_scope} scope."
    )
  end

  def authenticate_api_token!
    header = request.authorization.to_s
    if header.start_with?("Bearer ")
      raw = header.sub(/\ABearer\s+/, "").strip
      token = ApiToken.find_by_raw_token(raw)
      if token&.redeemable?
        Current.api_token = token
        return
      end
    end
    render_error(
      code: "unauthorized",
      status: :unauthorized,
      message: "Missing or invalid API token."
    )
  end
end
