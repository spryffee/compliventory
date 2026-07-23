# An internal vendor risk-assessment review record. In-progress rows are mutable
# working state (evidence checklist + summary); completing one freezes it into an
# immutable compliance record and stamps residual risk + review dates onto the
# vendor. Cancelling destroys the row (snapshot to the audit log), like asset
# rejection. See DESIGN-ASSESSMENT.md.
class Assessment < ApplicationRecord
  STATUSES = %w[in_progress completed].freeze
  RISK_LEVELS = %w[low medium high critical].freeze
  DECISIONS = %w[approved approved_with_conditions rejected].freeze

  # One evidence item per document kind; the shape stored in the jsonb array.
  EVIDENCE_KINDS = %w[soc2_report iso27001_cert dpa security_page pentest_summary other].freeze
  EVIDENCE_STATES = %w[pending reviewed not_applicable].freeze

  # Suggested months until next review, by residual risk (overridable on completion).
  REVIEW_MONTHS = { "critical" => 6, "high" => 12, "medium" => 24, "low" => 36 }.freeze

  belongs_to :asset, polymorphic: true
  belongs_to :assessor, class_name: "User"

  validates :status, inclusion: { in: STATUSES }
  validates :inherent_risk, inclusion: { in: RISK_LEVELS }, allow_nil: true
  validates :residual_risk, inclusion: { in: RISK_LEVELS }, allow_nil: true
  validates :decision, inclusion: { in: DECISIONS }, allow_nil: true
  validates :conditions, presence: true, if: -> { decision == "approved_with_conditions" }
  # A completed record is the compliance deliverable: it must carry an outcome.
  with_options if: :completed? do
    validates :residual_risk, :decision, :next_review_on, presence: true
  end
  validate :completed_records_are_immutable, on: :update

  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :for_asset, ->(asset) { where(asset: asset) }
  scope :newest_first, -> { order(created_at: :desc) }

  # The initial evidence checklist: one pending item per document kind.
  def self.blank_evidence
    EVIDENCE_KINDS.map { |kind| { "kind" => kind, "state" => "pending", "url" => nil, "notes" => nil } }
  end

  def in_progress?
    status == "in_progress"
  end

  def completed?
    status == "completed"
  end

  def audit_display
    "assessment of #{asset.name}"
  end

  private

  # Once completed, an assessment is a frozen compliance record: the completion
  # transition itself is allowed (the persisted status is still "in_progress"
  # during that save), but any later change is rejected. `status_in_database` is
  # the persisted value, the codebase idiom for "judge by what's stored, not the
  # in-memory assignment".
  def completed_records_are_immutable
    errors.add(:base, "completed assessments cannot be modified") if status_in_database == "completed"
  end
end
