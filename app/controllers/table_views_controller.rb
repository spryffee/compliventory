# Toggles the full-viewport table mode (DESIGN.md, "Dynamic tables"). The mode
# changes rows-per-page as well as layout, so it is a server round-trip rather
# than a class flipped in the browser: one render decides width, density and
# page size together, and they can never disagree.
class TableViewsController < ApplicationController
  # A relative path and nothing else — "//host" and "/\host" are ways of
  # writing another origin.
  RELATIVE_PATH = %r{\A/(?![/\\])}

  def update
    if params[:expanded] == "1"
      cookies[:table_view] = { value: "expanded", expires: 1.year.from_now, same_site: :lax }
    else
      cookies.delete(:table_view)
    end
    redirect_to return_path
  end

  private

  # The caller sends back the current filters and sort minus `page`: the toggle
  # changes rows-per-page, so page N points at different rows afterwards (and
  # may no longer exist).
  def return_path
    path = params[:return_to].to_s
    path.match?(RELATIVE_PATH) ? path : root_path
  end
end
