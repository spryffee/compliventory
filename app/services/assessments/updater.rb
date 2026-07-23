module Assessments
  # Saves working state on an in-progress assessment: the summary and/or a single
  # evidence checklist row (upserted by kind). This is mutable scratch space — no
  # audit event per edit; the completed record is the audit artifact.
  #
  # `evidence_item` is a permitted hash { kind:, state:, url:, notes: }; only a
  # known kind and state are accepted, so the checklist shape can't be corrupted.
  class Updater < ApplicationService
    def initialize(assessment:, actor:, summary: NOT_PROVIDED, evidence_item: nil)
      @assessment = assessment
      @actor = actor
      @summary = summary
      @evidence_item = evidence_item&.to_h&.symbolize_keys
    end

    def call
      return failure(:not_permitted) unless AssessmentPolicy.new(@actor, @assessment).may_edit?
      return failure(:not_in_progress) unless @assessment.in_progress?
      return failure(:invalid_evidence) if @evidence_item && !valid_evidence_item?

      @assessment.summary = @summary unless @summary == NOT_PROVIDED
      @assessment.evidence = merged_evidence if @evidence_item
      @assessment.save!
      success(@assessment)
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end

    private

    def valid_evidence_item?
      Assessment::EVIDENCE_KINDS.include?(@evidence_item[:kind].to_s) &&
        Assessment::EVIDENCE_STATES.include?(@evidence_item[:state].to_s)
    end

    def merged_evidence
      @assessment.evidence.map do |item|
        next item unless item["kind"] == @evidence_item[:kind].to_s

        item.merge(
          "state" => @evidence_item[:state].to_s,
          "url" => @evidence_item[:url].presence,
          "notes" => @evidence_item[:notes].presence
        )
      end
    end
  end
end
