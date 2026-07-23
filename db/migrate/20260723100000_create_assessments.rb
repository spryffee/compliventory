class CreateAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :assessments, id: :uuid do |t|
      t.references :asset, polymorphic: true, type: :uuid, null: false # Vendor only in v1
      t.references :assessor, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "in_progress"

      # snapshot at start (computed, then frozen)
      t.string :inherent_risk
      t.jsonb :inherent_risk_factors, null: false, default: []

      # working surface (mutable while in_progress)
      t.jsonb :evidence, null: false, default: []
      t.text :summary

      # set on completion
      t.string :residual_risk
      t.string :decision
      t.text :conditions
      t.date :next_review_on
      t.datetime :completed_at

      t.timestamps
    end

    # At most one in-progress assessment per asset.
    add_index :assessments, [ :asset_type, :asset_id ],
              unique: true, where: "status = 'in_progress'",
              name: "index_assessments_one_in_progress_per_asset"
  end
end
