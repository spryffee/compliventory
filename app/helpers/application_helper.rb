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

  # Enum-ish string / boolean / array values for read surfaces; blank → em dash.
  def display_value(value)
    case value
    when nil, "" then "—"
    when true    then "Yes"
    when false   then "No"
    when Array   then value.empty? ? "—" : value.map(&:humanize).join(", ")
    else value.to_s.humanize
    end
  end

  # Raw before/after values in audit diffs — no humanizing, free text stays
  # verbatim; blank → ∅ so "cleared" is visible.
  def audit_value(value)
    case value
    when nil, "" then "∅"
    when Array   then value.empty? ? "∅" : value.join(", ")
    else value.to_s
    end
  end

  # One labelled row on an asset detail page.
  def detail_row(label, value = nil, &block)
    content = block ? capture(&block) : value
    content = "—" if content.blank?
    tag.div(class: "px-5 py-2.5 grid grid-cols-3 gap-4") do
      tag.dt(label, class: "text-sm text-gray-500") +
        tag.dd(content, class: "col-span-2 text-sm text-gray-900")
    end
  end

  # A target descriptor from audit_events.targets — linked for asset types that
  # have detail pages. Hard-deleted targets keep their display name; the link
  # may 404, which is the history-in-audit-log trade-off.
  def audit_target_tag(target)
    label = target["display"] || target["id"]
    case target["type"]
    when "Vendor" then link_to label, vendor_path(target["id"]), class: "text-pine-700 hover:underline"
    when "System" then link_to label, system_path(target["id"]), class: "text-pine-700 hover:underline"
    else tag.span(label)
    end
  end

  def audit_timestamp(time)
    tag.time(time.strftime("%b %-d, %Y %H:%M"), datetime: time.iso8601, title: time.iso8601, class: "whitespace-nowrap")
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
