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

  has_many :systems

  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :data_location, inclusion: { in: DATA_LOCATIONS }, allow_nil: true
  validates :risk_tier, inclusion: { in: RISK_TIERS }, allow_nil: true
  validates :website, format: { with: %r{\Ahttps?://\S+\z}i }, allow_blank: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
