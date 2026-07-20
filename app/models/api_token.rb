class ApiToken < ApplicationRecord
  PREFIX = "cvt_".freeze
  # Single scope at MVP: users:write covers the whole sync API (upsert + list).
  # New scopes are additive when more API surfaces appear.
  SCOPES = %w[users:write].freeze

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :scope, inclusion: { in: SCOPES }

  # Token format: `cvt_<43 chars>` — 4-char prefix for grepability + secret-scanner
  # detection, plus 256 bits of entropy from urlsafe_base64(32).
  def self.generate_raw_token
    "#{PREFIX}#{SecureRandom.urlsafe_base64(32)}"
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  def self.find_by_raw_token(raw_token)
    return nil unless raw_token.is_a?(String) && raw_token.start_with?(PREFIX)
    find_by(token_digest: digest(raw_token))
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def redeemable?
    !expired?
  end

  def allows?(required_scope)
    scope == required_scope
  end
end
