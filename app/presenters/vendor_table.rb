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
    Column.new(key: "last_assessed_on", label: "Last assessed", sort: :last_assessed_on, default: false),
    Column.new(key: "next_review_on", label: "Next review", sort: :next_review_on, default: false),
    Column.new(key: "updated_at", label: "Updated", sort: :updated_at, default: false)
  ].freeze

  REVIEW_STATUS_OPTIONS = [
    [ "Overdue", "overdue" ], [ "Due in 30 days", "due_soon" ],
    [ "Never assessed", "never" ], [ "Up to date", "ok" ]
  ].freeze

  def filters
    [
      Filter.new(key: "status", label: "Status", options: Vendor::STATUSES.map { |s| [ s.humanize, s ] }),
      Filter.new(key: "category", label: "Category", options: Vendor::CATEGORIES.map { |c| [ c.humanize, c ] }),
      Filter.new(key: "risk_tier", label: "Risk tier", options: Vendor::RISK_TIERS.map { |t| [ t.humanize, t ] }),
      Filter.new(key: "review_status", label: "Review status", options: REVIEW_STATUS_OPTIONS),
      Filter.new(key: "owner_id", label: "Owner", options: owner_options)
    ]
  end

  private

  # Review status is derived from the denormalized assessment dates, not a
  # column, so it can't go through the generic column-equality filter.
  def apply_custom_filter(scope, key, value)
    return super unless key == "review_status"

    case value
    when "overdue"  then scope.active.where(next_review_on: ..Date.current)
    when "due_soon" then scope.active.where(next_review_on: (Date.current + 1)..(Date.current + 30))
    when "never"    then scope.active.where(last_assessed_on: nil)
    when "ok"       then scope.where(next_review_on: (Date.current + 31)..)
    else scope
    end
  end

  def base_scope
    Vendor.includes(:owner)
  end

  def owner_options
    User.where(id: Vendor.select(:owner_id)).order(:name).map { |u| [ u.name, u.id ] }
  end
end
