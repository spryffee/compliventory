# Vendor risk assessments, nested under a vendor. Reads are open to everyone
# (transparency); every write is gated by AssessmentPolicy and delegated to a
# service in app/services/assessments. See DESIGN-ASSESSMENT.md.
class AssessmentsController < ApplicationController
  before_action :set_vendor
  before_action :set_assessment, only: %i[show update complete destroy]

  helper_method :policy

  def show
    @inherent_risk = { level: @assessment.inherent_risk, factors: @assessment.inherent_risk_factors }
  end

  def create
    result = Assessments::Starter.call(vendor: @vendor, actor: current_user)
    if result.success
      redirect_to vendor_assessment_path(@vendor, result.value), notice: "Assessment started."
    elsif result.code == :not_permitted
      render "shared/forbidden", status: :forbidden
    else
      redirect_to @vendor, alert: start_error(result.code)
    end
  end

  def update
    result = Assessments::Updater.call(**updater_args)
    if result.success
      redirect_to vendor_assessment_path(@vendor, @assessment), notice: "Saved."
    elsif result.code == :validation_failed
      redirect_to vendor_assessment_path(@vendor, @assessment),
                  alert: "Could not save: #{error_messages(result)}."
    elsif result.code == :invalid_evidence
      redirect_to vendor_assessment_path(@vendor, @assessment), alert: "Unrecognized evidence update."
    else
      render "shared/forbidden", status: :forbidden
    end
  end

  def complete
    result = Assessments::Completer.call(
      assessment: @assessment, actor: current_user,
      residual_risk: params[:residual_risk], decision: params[:decision],
      conditions: params[:conditions], next_review_on: params[:next_review_on]
    )
    if result.success
      redirect_to vendor_assessment_path(@vendor, @assessment), notice: "Assessment completed."
    elsif result.code == :validation_failed
      redirect_to vendor_assessment_path(@vendor, @assessment),
                  alert: "Could not complete: #{error_messages(result)}."
    else
      render "shared/forbidden", status: :forbidden
    end
  end

  def destroy
    result = Assessments::Canceller.call(assessment: @assessment, actor: current_user)
    if result.success
      redirect_to @vendor, notice: "Assessment cancelled."
    else
      render "shared/forbidden", status: :forbidden
    end
  end

  private

  def policy
    @policy ||= AssessmentPolicy.new(current_user, @assessment)
  end

  def set_vendor
    @vendor = Vendor.find(params[:vendor_id])
  end

  def set_assessment
    @assessment = @vendor.assessments.find(params[:id])
  end

  # Pass summary only when the form carried it, so an evidence-row save doesn't
  # blank the summary (the Updater's NOT_PROVIDED sentinel default handles it).
  def updater_args
    args = { assessment: @assessment, actor: current_user }
    args[:summary] = params[:summary].to_s if params.key?(:summary)
    args[:evidence_item] = evidence_item_params if params[:evidence_item].present?
    args
  end

  def evidence_item_params
    params.require(:evidence_item).permit(:kind, :state, :url, :notes).to_h
  end

  def error_messages(result)
    result.context[:record].errors.full_messages.join(", ")
  end

  def start_error(code)
    case code
    when :not_assessable then "A vendor must be approved before it can be assessed."
    when :already_in_progress then "An assessment is already in progress for this vendor."
    else "Could not start the assessment."
    end
  end
end
