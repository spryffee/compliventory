class CreateVendors < ActiveRecord::Migration[8.1]
  def change
    create_table :vendors, id: :uuid do |t|
      t.string :name, null: false
      t.string :website
      t.text :description
      t.string :category
      t.string :status, null: false, default: "pending_approval"
      t.references :owner, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :contact_name
      t.string :contact_email
      t.text :notes

      # compliance-controlled (⚖)
      t.boolean :processes_personal_data
      t.string :data_location
      t.string :risk_tier

      t.timestamps
    end

    add_index :vendors, :name, unique: true
  end
end
