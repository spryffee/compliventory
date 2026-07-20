class System < ApplicationRecord
  include Asset

  STATUSES = %w[pending_approval active deprecated retired].freeze
  AUTHENTICATION_METHODS = %w[sso password_mfa password other].freeze
  CRITICALITIES = %w[low medium high critical].freeze
  DATA_CLASSIFICATIONS = %w[public internal confidential restricted].freeze
  PERSONAL_DATA_CATEGORIES = %w[employees candidates customers prospects partners special_categories].freeze

  # ⚖ fields — compliance-controlled (REQUIREMENTS.md, "Change control").
  COMPLIANCE_FIELDS = %i[criticality data_classification stores_personal_data personal_data_categories].freeze

  COMPLIANCE_SET_ONLY_FIELDS = %i[].freeze

  # Everything an editor can touch through the edit form, in form order.
  EDITABLE_FIELDS = %i[
    name vendor_id description status owner_id technical_owner_id
    department url authentication_method notes
    criticality data_classification stores_personal_data personal_data_categories
  ].freeze

  belongs_to :vendor, optional: true
  belongs_to :technical_owner, class_name: "User", optional: true

  validates :authentication_method, inclusion: { in: AUTHENTICATION_METHODS }, allow_nil: true
  validates :criticality, inclusion: { in: CRITICALITIES }, allow_nil: true
  validates :data_classification, inclusion: { in: DATA_CLASSIFICATIONS }, allow_nil: true
  validates :url, format: { with: %r{\Ahttps?://\S+\z}i }, allow_blank: true
  validate :personal_data_categories_are_known

  # Checkbox form posts include a blank sentinel; drop it on the way in.
  def personal_data_categories=(value)
    super(Array(value).reject(&:blank?))
  end

  private

  def personal_data_categories_are_known
    unknown = personal_data_categories - PERSONAL_DATA_CATEGORIES
    errors.add(:personal_data_categories, "contains unknown categories: #{unknown.join(', ')}") if unknown.any?
  end
end
