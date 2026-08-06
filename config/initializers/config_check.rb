# Fail the deploy rather than the first user. Everything checked here has no safe
# default in production: an unset COMPLIVENTORY_HOST silently mails links to
# localhost and builds the OIDC redirect_uri against it, and missing OIDC
# credentials only surface when somebody tries to sign in.
#
# SECRET_KEY_BASE is deliberately NOT checked. Rails already refuses to boot
# without a secret, and requiring the variable would break the legitimate case of
# building from source with your own credentials file, where it lives there
# instead.
module Compliventory
  OIDC_VARS = %w[OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET].freeze

  # Everything wrong with the given environment; empty when it is fit to serve.
  # Split out from the raise below so it is testable without booting a second app.
  def self.config_problems(env = ENV)
    problems = []
    host = env["COMPLIVENTORY_HOST"]

    if host.blank?
      problems << "COMPLIVENTORY_HOST is not set. Email links and the OIDC redirect_uri would point at http://localhost:3000."
    else
      uri = URI.parse(host) rescue nil
      unless uri&.scheme&.match?(/\Ahttps?\z/) && uri.host.present?
        problems << "COMPLIVENTORY_HOST is not an absolute URL (got #{host.inspect}). Use e.g. https://compliventory.example.com."
      end
    end

    unless ActiveModel::Type::Boolean.new.cast(env["DEMO_MODE"])
      OIDC_VARS.each do |var|
        problems << "#{var} is not set. Nobody can sign in without the OIDC client configured." if env[var].blank?
      end
    end

    problems
  end
end

# `assets:precompile` boots the app in production during the image build, long
# before any of this is knowable; Rails' own dummy-secret flag marks that boot.
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  problems = Compliventory.config_problems
  if problems.any?
    raise "compliventory cannot start:\n#{problems.map { |p| "  - #{p}" }.join("\n")}"
  end
end
