class SystemsController < AssetsController
  private

  def asset_class
    System
  end

  def table_class
    SystemTable
  end
end
