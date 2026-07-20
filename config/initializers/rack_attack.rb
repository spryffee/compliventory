require "ipaddr"

# Middleware-layer abuse throttling on the auth and API surfaces (DESIGN.md).
# Storage is Rails.cache — Solid Cache in production, memory store in development.
# Disabled in test by default; the throttle test flips `Rack::Attack.enabled` on
# with a real cache store.
class Rack::Attack
  # --- backing store ---------------------------------------------------------
  self.cache.store = Rails.cache

  # --- operator-configurable safelist ---------------------------------------
  # RATE_LIMIT_SAFELIST = comma-separated CIDRs (corporate egress, monitoring).
  SAFELIST_CIDRS = ENV.fetch("RATE_LIMIT_SAFELIST", "")
                      .split(",")
                      .filter_map { |c| IPAddr.new(c.strip) rescue nil }

  safelist("safelist by CIDR") do |req|
    SAFELIST_CIDRS.any? { |net| net.include?(req.ip) }
  rescue IPAddr::Error
    false
  end

  # --- API: per-IP and per-token -------------------------------------------
  throttle("api/ip", limit: 600, period: 60) do |req|
    req.ip if req.path.start_with?("/api/v1")
  end

  # Per-consumer (token) cap across ALL source IPs — bounds a distributed
  # consumer the per-IP rule can't see. Keyed by token digest — never the raw
  # secret in the cache key.
  throttle("api/token", limit: 3000, period: 60) do |req|
    next unless req.path.start_with?("/api/v1")

    header = req.get_header("HTTP_AUTHORIZATION").to_s
    if header.start_with?("Bearer ")
      Digest::SHA256.hexdigest(header.sub(/\ABearer\s+/, "").strip)
    end
  end

  # --- Auth surface: per-IP --------------------------------------------------
  # OIDC request phase (POST /auth/oidc, handled by OmniAuth middleware).
  throttle("auth/ip", limit: 5, period: 20) do |req|
    req.ip if req.post? && req.path.start_with?("/auth/")
  end

  # --- 429 responder ---------------------------------------------------------
  # Mirrors the API error envelope so consumers branch on error.code uniformly.
  self.throttled_responder = lambda do |req|
    match = req.env["rack.attack.match_data"] || {}
    period = match[:period].to_i
    retry_after = period.positive? ? (period - (Time.now.to_i % period)) : 60

    body = {
      "error" => {
        "code" => "rate_limited",
        "message" => "Too many requests; slow down and retry after the indicated interval.",
        "details" => { "retry_after" => retry_after }
      }
    }.to_json

    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ body ]
    ]
  end
end

Rack::Attack.enabled = false if Rails.env.test?
