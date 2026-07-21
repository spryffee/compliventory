# Declarative config + query builder for the dynamic asset tables (DESIGN.md,
# "Dynamic tables"): every column sortable against an allowlist, per-column
# select filters + ILIKE text search from query params, user-selected visible
# columns persisted in users.ui_preferences. One presenter, two configs
# (VendorTable / SystemTable).
class AssetTable
  Column = Data.define(:key, :label, :sort, :default)
  Filter = Data.define(:key, :label, :options)
  # Sort by a joined table's column, expressed in Arel (no raw SQL).
  JoinSort = Data.define(:join, :attribute)

  SORT_DIRS = %w[asc desc].freeze

  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def asset_class
    self.class::ASSET_CLASS
  end

  def columns
    self.class::COLUMNS
  end

  def column_keys
    columns.map(&:key)
  end

  # The chosen set intersected with the config (stale prefs drop out); empty →
  # defaults. "name" is always shown — it is the link to the record.
  def visible_columns
    chosen = Array(@user.ui_preferences[preference_key]).map(&:to_s) & column_keys
    chosen = columns.select(&:default).map(&:key) if chosen.empty?
    chosen |= [ "name" ]
    columns.select { |column| chosen.include?(column.key) }
  end

  def scope
    apply_sort(apply_filters(apply_search(base_scope)))
  end

  def query
    @params[:q].to_s.strip
  end

  def filter_value(key)
    @params[key].presence
  end

  def filtered?
    query.present? || filters.any? { |filter| filter_value(filter.key) }
  end

  def sort_key
    key = @params[:sort].to_s
    sorts.key?(key) ? key : "name"
  end

  def sort_dir
    SORT_DIRS.include?(@params[:dir]) ? @params[:dir] : "asc"
  end

  def preference_key
    "#{table_key}_table_columns"
  end

  def table_key
    self.class::ASSET_CLASS.table_name
  end

  private

  def sorts
    @sorts ||= columns.to_h { |column| [ column.key, column.sort ] }
  end

  def base_scope
    self.class::ASSET_CLASS.all
  end

  def apply_search(scope)
    return scope if query.blank?
    like = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    arel = asset_class.arel_table
    scope.where(arel[:name].matches(like).or(arel[:description].matches(like)))
  end

  def apply_filters(scope)
    filters.reduce(scope) do |current, filter|
      value = filter_value(filter.key)
      value ? current.where(filter.key => value) : current
    end
  end

  def apply_sort(scope)
    case (sort = sorts.fetch(sort_key))
    when JoinSort
      scope.left_outer_joins(sort.join).order(sort.attribute.public_send(sort_dir)).order(:name)
    else
      scope.order(sort => sort_dir.to_sym).order(:name)
    end
  end
end
