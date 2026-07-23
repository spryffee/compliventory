class AddAssessmentDatesToVendors < ActiveRecord::Migration[8.1]
  def change
    # Denormalized so the vendors table sorts/filters without joining assessments.
    # Maintained only by Assessments::Completer; not in Vendor::EDITABLE_FIELDS.
    add_column :vendors, :last_assessed_on, :date
    add_column :vendors, :next_review_on, :date
  end
end
