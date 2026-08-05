class User < ApplicationRecord
  ROLES = %w[member compliance admin].freeze

  normalizes :email, with: ->(email) { email.strip.downcase }

  # Users arrive from an external IdP through the sync API, so the format check
  # belongs on the model — same regexp as Vendor#contact_email.
  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }

  # `active: false` blocks login and removes the user from owner pickers,
  # nothing else — no state machine (see DESIGN.md).
  scope :active, -> { where(active: true) }

  def member?
    role == "member"
  end

  def compliance?
    role == "compliance"
  end

  def admin?
    role == "admin"
  end
end
