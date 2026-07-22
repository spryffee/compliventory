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
    has_many :change_proposals, as: :asset, dependent: :destroy

    validates :name, presence: true, uniqueness: true
    validates :status, inclusion: { in: ->(record) { record.class::STATUSES } }

    scope :pending_approval, -> { where(status: "pending_approval") }
  end

  def pending_approval?
    status == "pending_approval"
  end

  # Ownership is judged by the PERSISTED owner, never an owner_id assigned in
  # memory. Otherwise an editor could self-assign ownership (owner_id = self) and
  # pass the owner-only edit gate before the change is ever reviewed — a
  # privilege escalation, since the Editor checks this right after
  # assign_attributes. `_in_database` is the stored value (nil for a new record,
  # where the freshly-set owner_id is the right thing to trust).
  def owned_or_delegated_to?(user)
    current_owner_id = owner_id_in_database || owner_id
    current_owner_id == user.id || delegations.exists?(user_id: user.id)
  end

  # "vendor" / "system" — prefix for audit event types (vendor.updated, …).
  def audit_event_prefix
    model_name.singular
  end
end
