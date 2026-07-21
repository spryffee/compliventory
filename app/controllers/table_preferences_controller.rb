# Persists the column-picker selection (DESIGN.md, "Dynamic tables") in
# users.ui_preferences so it follows the user across devices. Unknown column
# keys are dropped; an empty selection falls back to the table's defaults.
class TablePreferencesController < ApplicationController
  TABLES = { "vendors" => VendorTable, "systems" => SystemTable }.freeze

  def update
    table = TABLES[params[:table]]&.new(user: current_user, params: params)
    return head :bad_request unless table

    chosen = Array(params[:columns]).map(&:to_s) & table.column_keys
    current_user.update!(ui_preferences: current_user.ui_preferences.merge(table.preference_key => chosen))
    redirect_back fallback_location: root_path
  end
end
