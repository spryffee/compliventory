class User < ApplicationRecord
  ROLES = %w[member compliance admin].freeze

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
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
