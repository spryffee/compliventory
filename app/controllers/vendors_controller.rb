class VendorsController < AssetsController
  # Adds the risk data the Vendor detail's Risk panel needs on top of the shared
  # asset show (proposals + audit trail). Inherent risk is computed live so the
  # panel reflects the current inventory, not a stale snapshot.
  def show
    super
    @assessments = @asset.assessments.newest_first.includes(:assessor)
    @in_progress_assessment = @assessments.detect(&:in_progress?)
    @inherent_risk = Assessments::InherentRisk.call(@asset)
    @assessment_policy = AssessmentPolicy.new(current_user, @in_progress_assessment)
  end

  private

  def asset_class
    Vendor
  end

  def table_class
    VendorTable
  end
end
