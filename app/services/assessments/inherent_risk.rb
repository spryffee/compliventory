module Assessments
  # Computes a vendor's inherent risk — the risk before any controls — purely
  # from inventory fields already on record: the vendor's own flags plus the risk
  # fields of the active/deprecated systems linked to it. No persistence.
  #
  # Highest level wins. Returns { level:, factors: } where:
  #   - level is one of Assessment::RISK_LEVELS, or nil ("unscored") when nothing
  #     is known about the vendor's risk;
  #   - factors is the list of elevating reasons (one per distinct factor, at its
  #     highest contribution), sorted by level desc, each a string-keyed hash
  #     { "factor" => key, "value" => observed, "level" => contributed } so a live
  #     call and a jsonb-persisted snapshot read identically.
  #
  # See DESIGN-ASSESSMENT.md, "Inherent risk scoring".
  class InherentRisk
    # Only these system statuses hold live risk (retired/pending are excluded).
    COUNTED_SYSTEM_STATUSES = %w[active deprecated].freeze

    RISK_RANK = Assessment::RISK_LEVELS.each_with_index.to_h.freeze

    def self.call(vendor)
      new(vendor).call
    end

    def initialize(vendor)
      @vendor = vendor
      @systems = vendor.systems.select { |system| COUNTED_SYSTEM_STATUSES.include?(system.status) }
    end

    def call
      factors = detect_factors
      { level: level_for(factors), factors: factors }
    end

    private

    attr_reader :vendor, :systems

    def detect_factors
      [
        data_classification_factor,
        criticality_factor,
        special_category_factor,
        personal_data_factor,
        data_location_factor,
        infrastructure_factor
      ].compact.sort_by { |factor| -RISK_RANK.fetch(factor["level"]) }
    end

    def level_for(factors)
      return factors.first["level"] if factors.any?
      return "low" if anything_known?

      nil
    end

    def data_classification_factor
      if systems.any? { |system| system.data_classification == "restricted" }
        factor("system_data_classification", "restricted", "critical")
      elsif systems.any? { |system| system.data_classification == "confidential" }
        factor("system_data_classification", "confidential", "high")
      end
    end

    def criticality_factor
      if systems.any? { |system| system.criticality == "critical" }
        factor("system_criticality", "critical", "critical")
      elsif systems.any? { |system| system.criticality == "high" }
        factor("system_criticality", "high", "high")
      end
    end

    def special_category_factor
      return unless systems.any? { |system| system.personal_data_categories.include?("special_categories") }

      factor("special_category_personal_data", "special_categories", "high")
    end

    def personal_data_factor
      return unless vendor.processes_personal_data || systems.any?(&:stores_personal_data)

      factor("personal_data", "present", "medium")
    end

    def data_location_factor
      factor("data_location", "other", "medium") if vendor.data_location == "other"
    end

    def infrastructure_factor
      factor("infrastructure_vendor", "cloud_infra", "medium") if vendor.category == "cloud_infra"
    end

    def factor(key, value, level)
      { "factor" => key, "value" => value, "level" => level }
    end

    # "Known" = we have at least one real risk signal to judge by. Category and
    # data location alone aren't signals (a "saas" vendor tells us nothing about
    # data risk), so per DESIGN-ASSESSMENT.md the test is: the vendor's
    # personal-data flag is set, or some counted system has a ⚖ field set.
    def anything_known?
      !vendor.processes_personal_data.nil? || systems.any? { |system| system_risk_known?(system) }
    end

    def system_risk_known?(system)
      system.criticality.present? || system.data_classification.present? ||
        !system.stores_personal_data.nil? || system.personal_data_categories.present?
    end
  end
end
