class Vendor < ApplicationRecord
  include Asset

  CATEGORIES = %w[saas cloud_infra software services other].freeze
  STATUSES = %w[pending_approval active offboarded archived].freeze
  DATA_LOCATIONS = %w[eu us other].freeze
  RISK_TIERS = %w[low medium high critical].freeze

  # ⚖ fields — compliance-controlled (REQUIREMENTS.md, "Change control").
  COMPLIANCE_FIELDS = %i[processes_personal_data data_location risk_tier].freeze

  # Compliance-set only: not proposable, stripped from non-compliance submissions.
  COMPLIANCE_SET_ONLY_FIELDS = %i[risk_tier].freeze

  # Everything an editor can touch through the edit form, in form order.
  EDITABLE_FIELDS = %i[
    name website description category status owner_id
    contact_name contact_email notes
    processes_personal_data data_location risk_tier
  ].freeze

  # Rejecting a pending vendor destroys the row. Systems pointing at it must be
  # detached first: nullifying vendor_id here would silently re-classify them as
  # in-house, and cascading would delete inventory nobody asked to remove. The
  # Rejecter guards this explicitly; this is the backstop (and the FK's, which
  # would otherwise surface as a 500).
  has_many :systems, dependent: :restrict_with_error
  has_many :assessments, as: :asset, dependent: :destroy

  # The review queue, defined once and shared by /compliance, the weekly digest
  # and the vendors table's review-status filter — three surfaces that answered
  # "needs a review?" separately, and disagreed.
  scope :review_overdue, -> { active.where(next_review_on: ..Date.current) }
  scope :review_due_soon, -> { active.where(next_review_on: (Date.current + 1)..(Date.current + 30)) }
  scope :never_assessed, -> { active.where(last_assessed_on: nil) }
  # Not scoped to active, unlike its neighbours: an archived vendor with a future
  # date still reads as up to date in the table filter. Kept as it was.
  scope :review_up_to_date, -> { where(next_review_on: (Date.current + 31)..) }
  # Someone is already on it, so it belongs on no queue.
  scope :not_under_assessment, -> {
    where.not(id: Assessment.in_progress.where(asset_type: "Vendor").select(:asset_id))
  }

  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :data_location, inclusion: { in: DATA_LOCATIONS }, allow_nil: true
  validates :risk_tier, inclusion: { in: RISK_TIERS }, allow_nil: true
  validates :website, format: { with: %r{\Ahttps?://\S+\z}i }, allow_blank: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
