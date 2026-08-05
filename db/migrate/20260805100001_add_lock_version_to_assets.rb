class AddLockVersionToAssets < ActiveRecord::Migration[8.1]
  def change
    # Two delegates editing the same record silently last-write-wins without it.
    add_column :vendors, :lock_version, :integer, default: 0, null: false
    add_column :systems, :lock_version, :integer, default: 0, null: false
  end
end
