class SystemTable < AssetTable
  ASSET_CLASS = System

  COLUMNS = [
    Column.new(key: "name", label: "Name", sort: :name, default: true),
    Column.new(key: "vendor", label: "Vendor", sort: JoinSort.new(join: :vendor, attribute: Vendor.arel_table[:name]), default: true),
    Column.new(key: "status", label: "Status", sort: :status, default: true),
    Column.new(key: "criticality", label: "Criticality", sort: :criticality, default: true),
    Column.new(key: "owner", label: "Owner", sort: JoinSort.new(join: :owner, attribute: User.arel_table[:name]), default: true),
    Column.new(key: "department", label: "Department", sort: :department, default: false),
    Column.new(key: "data_classification", label: "Data classification", sort: :data_classification, default: false),
    Column.new(key: "authentication_method", label: "Authentication", sort: :authentication_method, default: false),
    Column.new(key: "stores_personal_data", label: "Personal data", sort: :stores_personal_data, default: false),
    Column.new(key: "updated_at", label: "Updated", sort: :updated_at, default: false)
  ].freeze

  def filters
    [
      Filter.new(key: "status", label: "Status", options: System::STATUSES.map { |s| [ s.humanize, s ] }),
      Filter.new(key: "criticality", label: "Criticality", options: System::CRITICALITIES.map { |c| [ c.humanize, c ] }),
      Filter.new(key: "data_classification", label: "Data classification", options: System::DATA_CLASSIFICATIONS.map { |d| [ d.humanize, d ] }),
      Filter.new(key: "vendor_id", label: "Vendor", options: vendor_options),
      Filter.new(key: "owner_id", label: "Owner", options: owner_options)
    ]
  end

  private

  def base_scope
    System.includes(:owner, :vendor)
  end

  def vendor_options
    Vendor.where(id: System.select(:vendor_id)).order(:name).map { |v| [ v.name, v.id ] }
  end

  def owner_options
    User.where(id: System.select(:owner_id)).order(:name).map { |u| [ u.name, u.id ] }
  end
end
