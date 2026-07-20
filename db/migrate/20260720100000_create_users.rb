class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :role, null: false, default: "member"   # member | compliance | admin
      t.boolean :active, null: false, default: true

      # Per-user UI state (dynamic-table column selections etc.). Server-rendered
      # tables read this, so preferences follow the user across devices.
      t.jsonb :ui_preferences, null: false, default: {}

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
