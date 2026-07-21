class VendorsController < AssetsController
  private

  def asset_class
    Vendor
  end

  def table_class
    VendorTable
  end
end
