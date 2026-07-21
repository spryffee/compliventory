class CreateChangeProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :change_proposals, id: :uuid do |t|
      t.references :asset, polymorphic: true, type: :uuid, null: false
      t.references :proposer, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :lane, null: false
      # `changes` would shadow ActiveModel::Dirty — same rename as audit_events.
      t.jsonb :attribute_changes, null: false
      t.text :justification

      t.timestamps
    end

    add_index :change_proposals, :lane
  end
end
