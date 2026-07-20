class SystemsController < AssetsController
  private

  def asset_class
    System
  end

  def asset_scope
    System.includes(:owner, :vendor).order(:name)
  end
end
