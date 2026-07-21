class VendorTable < AssetTable
  ASSET_CLASS = Vendor

  COLUMNS = [
    Column.new(key: "name", label: "Name", sort: :name, default: true),
    Column.new(key: "category", label: "Category", sort: :category, default: true),
    Column.new(key: "status", label: "Status", sort: :status, default: true),
    Column.new(key: "risk_tier", label: "Risk tier", sort: :risk_tier, default: true),
    Column.new(key: "owner", label: "Owner", sort: JoinSort.new(join: :owner, attribute: User.arel_table[:name]), default: true),
    Column.new(key: "data_location", label: "Data location", sort: :data_location, default: false),
    Column.new(key: "processes_personal_data", label: "Personal data", sort: :processes_personal_data, default: false),
    Column.new(key: "contact_email", label: "Contact", sort: :contact_email, default: false),
    Column.new(key: "updated_at", label: "Updated", sort: :updated_at, default: false)
  ].freeze

  def filters
    [
      Filter.new(key: "status", label: "Status", options: Vendor::STATUSES.map { |s| [ s.humanize, s ] }),
      Filter.new(key: "category", label: "Category", options: Vendor::CATEGORIES.map { |c| [ c.humanize, c ] }),
      Filter.new(key: "risk_tier", label: "Risk tier", options: Vendor::RISK_TIERS.map { |t| [ t.humanize, t ] }),
      Filter.new(key: "owner_id", label: "Owner", options: owner_options)
    ]
  end

  private

  def base_scope
    Vendor.includes(:owner)
  end

  def owner_options
    User.where(id: Vendor.select(:owner_id)).order(:name).map { |u| [ u.name, u.id ] }
  end
end
