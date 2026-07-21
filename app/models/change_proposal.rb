# A pending change to an asset's fields. Rows are pending BY DEFINITION:
# approve/reject emits the audit event (full diff, decision, comment, actor)
# and destroys the row — state lives in the row, history in the audit log.
class ChangeProposal < ApplicationRecord
  LANES = %w[owner compliance].freeze

  belongs_to :asset, polymorphic: true
  belongs_to :proposer, class_name: "User"

  validates :lane, inclusion: { in: LANES }
  validates :attribute_changes, presence: true

  scope :owner_lane, -> { where(lane: "owner") }
  scope :compliance_lane, -> { where(lane: "compliance") }
  scope :oldest_first, -> { order(:created_at) }

  # Owner-lane proposals awaiting the given user: proposals on assets they own
  # or are delegated on.
  def self.for_owner_inbox(user)
    vendor_ids = Vendor.where(owner_id: user.id).ids |
                 Delegation.where(user: user, asset_type: "Vendor").pluck(:asset_id)
    system_ids = System.where(owner_id: user.id).ids |
                 Delegation.where(user: user, asset_type: "System").pluck(:asset_id)

    owner_lane.where(asset_type: "Vendor", asset_id: vendor_ids)
              .or(owner_lane.where(asset_type: "System", asset_id: system_ids))
  end

  # `attribute_changes` stores the base value ({ field => [base, proposed] }).
  # No hard conflict resolution at MVP: the review screen shows base →
  # current → proposed for stale fields; approving applies the proposed value.
  def base_value(field)
    attribute_changes.fetch(field).first
  end

  def proposed_value(field)
    attribute_changes.fetch(field).last
  end

  def current_value(field)
    asset[field]
  end

  def stale?(field)
    current_value(field) != base_value(field)
  end

  # { field => proposed } — the write set an approval applies.
  def proposed_attributes
    attribute_changes.transform_values(&:last)
  end

  # Who should hear about (and may decide) this proposal — minus the proposer,
  # who doesn't need to be told about their own edit.
  def reviewers
    reviewers = case lane
    when "owner"      then ([ asset.owner ] + asset.delegates).select(&:active?)
    when "compliance" then User.active.where(role: "compliance").to_a
    end
    (reviewers - [ proposer ]).uniq
  end

  def audit_display
    "#{lane} proposal on #{asset.name}"
  end
end
