# Abstract base for the two inventory asset types. Subclasses define
# `asset_class`; everything else — direct-path CRUD, the submission flow,
# per-field permission filtering — is shared (vendors and systems share
# mechanics by design).
class AssetsController < ApplicationController
  include Pagy::Method

  before_action :set_asset, only: %i[show edit update approve reject]

  helper_method :policy

  def index
    @pagy, @assets = pagy(:offset, asset_scope, limit: 25)
  end

  def show
    @proposals = @asset.change_proposals.includes(:proposer).oldest_first
    @audit_events = AuditEvent.for_target(@asset).recent_first.limit(30)
  end

  def new
    @asset = asset_class.new(owner_id: current_user.id)
    @form_fields = submission_fields
  end

  def create
    result = Assets::Submitter.call(asset_class: asset_class, actor: current_user, attributes: submission_params)
    if result.success
      notice = result.value.pending_approval? ? "Submitted for compliance approval." : "Created."
      redirect_to result.value, notice: notice
    else
      @asset = result.context[:record]
      @form_fields = submission_fields
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @form_fields = policy.editable_fields
  end

  def update
    result = Assets::Editor.call(
      asset: @asset, actor: current_user,
      attributes: edit_params, justification: params[:justification]
    )
    if result.success
      redirect_to @asset, notice: outcome_notice(result.value)
    elsif result.code == :validation_failed
      @asset = result.context[:record]
      @form_fields = policy.editable_fields
      render :edit, status: :unprocessable_content
    else
      render "shared/forbidden", status: :forbidden
    end
  end

  # Compliance decisions on pending submissions — the only pending_approval →
  # active path (approve), or hard delete with an audited snapshot (reject).
  def approve
    result = Assets::Approver.call(asset: @asset, actor: current_user, comment: params[:comment])
    if result.success
      redirect_to compliance_path, notice: "#{@asset.name} approved — now active."
    else
      decision_failure(result)
    end
  end

  def reject
    name = @asset.name
    result = Assets::Rejecter.call(asset: @asset, actor: current_user, comment: params[:comment])
    if result.success
      redirect_to compliance_path, notice: "#{name} rejected and removed. The snapshot is in the audit log."
    else
      decision_failure(result)
    end
  end

  private

  def asset_class
    raise NotImplementedError
  end

  def asset_scope
    asset_class.includes(:owner).order(:name)
  end

  def set_asset
    @asset = asset_class.find(params[:id])
  end

  def policy
    @policy ||= AssetPolicy.for(current_user, @asset)
  end

  def outcome_notice(outcome)
    parts = []
    parts << "Changes saved." if outcome.applied_changes.any?
    outcome.proposals.each do |proposal|
      reviewer = proposal.lane == "compliance" ? "compliance" : "the owner"
      parts << "#{proposal.attribute_changes.size} #{'change'.pluralize(proposal.attribute_changes.size)} sent to #{reviewer} for review."
    end
    parts.empty? ? "No changes." : parts.join(" ")
  end

  def decision_failure(result)
    if result.code == :not_pending
      redirect_to @asset, alert: "Only pending submissions can be decided."
    else
      render "shared/forbidden", status: :forbidden
    end
  end

  # Submissions may set everything except status (the Submitter decides it) and
  # compliance-set-only fields for non-compliance actors.
  def submission_fields
    fields = asset_class::EDITABLE_FIELDS - [ :status ]
    fields -= asset_class::COMPLIANCE_SET_ONLY_FIELDS unless current_user.compliance?
    fields
  end

  def submission_params
    permit_fields(submission_fields)
  end

  def edit_params
    permit_fields(policy.editable_fields)
  end

  def permit_fields(fields)
    keys = fields.map { |f| f == :personal_data_categories ? { personal_data_categories: [] } : f }
    params.require(asset_class.model_name.param_key).permit(*keys)
  end
end
