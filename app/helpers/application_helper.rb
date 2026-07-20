module ApplicationHelper
  def input_class
    "input"
  end

  # A calm dot-chip: neutral chip + a single semantic dot. Keeps the monochrome
  # brand while making status scannable. Covers vendor and system lifecycles.
  def status_pill(status)
    dot = case status
    when "active"                            then "bg-emerald-500"
    when "pending_approval"                  then "bg-amber-500"
    when "deprecated"                        then "bg-orange-500"
    when "offboarded", "retired", "archived" then "bg-red-500"
    else "bg-gray-400"
    end
    tag.span(class: "pill bg-gray-100 text-gray-700") do
      safe_join([ tag.span("", class: "w-1.5 h-1.5 rounded-full #{dot}"), status.humanize ])
    end
  end

  # The compliventory mark: three shelf slabs, top one pine.
  def brand_mark(css_class: "w-7 h-7")
    tag.svg(class: css_class, viewBox: "0 0 48 48", "aria-hidden": true) do
      safe_join([
        tag.rect(x: 10, y: 9,  width: 28, height: 8, rx: 1.5, fill: "#1f8a78"),
        tag.rect(x: 10, y: 20, width: 28, height: 8, rx: 1.5, fill: "#0f0f0f"),
        tag.rect(x: 10, y: 31, width: 28, height: 8, rx: 1.5, fill: "#0f0f0f")
      ])
    end
  end
end
