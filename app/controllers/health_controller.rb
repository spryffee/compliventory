# Kamal gates a rollout on this endpoint, so it has to answer for the database
# too: a container whose Postgres is unreachable would otherwise report healthy
# and be given traffic. Only the primary database is checked — the queue and
# cache being down degrades the app rather than breaking it, and a health check
# strict enough to fail on those would roll back deploys that should stand.
#
# Inherits ActionController::Base directly, so no authentication, audit context
# or layout applies. The body stays empty on purpose: the endpoint is public.
class HealthController < ActionController::Base
  def show
    ActiveRecord::Base.connection.select_value("SELECT 1")
    head :ok
  rescue StandardError => e
    Rails.logger.error("Health check failed: #{e.class}: #{e.message}")
    head :service_unavailable
  end
end
