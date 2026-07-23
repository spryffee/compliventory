# View bits for the dynamic asset tables (shared/_asset_table).
module AssetTablesHelper
  # Free-text fields that must not be humanized by display_value.
  VERBATIM_KEYS = %w[contact_email department].freeze

  # One body cell, keyed by the presenter's column key. Anything not
  # special-cased is an enum-ish/boolean/array field display_value handles.
  def asset_cell(asset, key)
    case key
    when "name" then link_to asset.name, asset, class: "text-gray-900 hover:text-pine-700"
    when "status" then status_pill(asset.status)
    when "owner" then asset.owner.name
    when "vendor" then asset.vendor ? link_to(asset.vendor.name, asset.vendor, class: "hover:text-pine-700") : "In-house"
    when "updated_at" then asset.updated_at.strftime("%b %-d, %Y")
    when "last_assessed_on" then asset.last_assessed_on&.strftime("%b %-d, %Y") || "—"
    when "next_review_on" then review_due_tag(asset.next_review_on)
    when *VERBATIM_KEYS then asset.public_send(key).presence || "—"
    else display_value(asset.public_send(key))
    end
  end

  # Header link: toggles direction on the active column, keeps search/filters,
  # resets pagination.
  def table_sort_link(table, column)
    active = table.sort_key == column.key
    dir = active && table.sort_dir == "asc" ? "desc" : "asc"
    query = request.query_parameters.except("page").merge("sort" => column.key, "dir" => dir).symbolize_keys
    link_to url_for(query), class: "inline-flex items-center gap-1 hover:text-gray-900" do
      indicator = tag.span(table.sort_dir == "asc" ? "↑" : "↓", class: "text-gray-400") if active
      safe_join([ column.label, indicator ].compact)
    end
  end
end
