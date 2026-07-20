class CreateSystems < ActiveRecord::Migration[8.1]
  def change
    create_table :systems, id: :uuid do |t|
      t.string :name, null: false
      t.references :vendor, type: :uuid, foreign_key: true # nullable — internal systems
      t.text :description
      t.string :status, null: false, default: "pending_approval"
      t.references :owner, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :technical_owner, type: :uuid, foreign_key: { to_table: :users }
      t.string :department
      t.string :url
      t.string :authentication_method
      t.text :notes

      # compliance-controlled (⚖)
      t.string :criticality
      t.string :data_classification
      t.boolean :stores_personal_data
      t.string :personal_data_categories, array: true, default: []

      t.timestamps
    end

    add_index :systems, :name, unique: true
  end
end
