class Delegation < ApplicationRecord
  belongs_to :asset, polymorphic: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: %i[asset_type asset_id] }
end
