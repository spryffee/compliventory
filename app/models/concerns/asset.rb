# Shared mechanics of the two inventory asset types (Vendor and System):
# ownership, delegations, lifecycle status. Owner + delegates are functionally
# equal in-app; `owner_id` is the accountability pointer (REQUIREMENTS.md,
# "Ownership model").
module Asset
  extend ActiveSupport::Concern

  included do
    belongs_to :owner, class_name: "User"

    has_many :delegations, as: :asset, dependent: :destroy
    has_many :delegates, through: :delegations, source: :user

    validates :name, presence: true, uniqueness: true
    validates :status, inclusion: { in: ->(record) { record.class::STATUSES } }

    scope :pending_approval, -> { where(status: "pending_approval") }
  end

  def pending_approval?
    status == "pending_approval"
  end

  def owned_or_delegated_to?(user)
    owner_id == user.id || delegations.exists?(user_id: user.id)
  end

  # "vendor" / "system" — prefix for audit event types (vendor.updated, …).
  def audit_event_prefix
    model_name.singular
  end
end
