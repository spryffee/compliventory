class CreateDelegations < ActiveRecord::Migration[8.1]
  def change
    create_table :delegations, id: :uuid do |t|
      t.references :asset, polymorphic: true, type: :uuid, null: false
      t.references :user, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end

    add_index :delegations, [ :asset_type, :asset_id, :user_id ], unique: true
  end
end
