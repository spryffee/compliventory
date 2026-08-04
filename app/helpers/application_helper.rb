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

  # Semantic dot colour per risk level, shared by the pill and the indicator.
  RISK_DOT = { "low" => "bg-emerald-500", "medium" => "bg-amber-500",
               "high" => "bg-orange-500", "critical" => "bg-red-500" }.freeze

  # A risk-level dot-chip (inherent or residual), matching status_pill's calm
  # monochrome style. Blank level → "Unscored".
  def risk_pill(level)
    return tag.span("Unscored", class: "pill bg-gray-100 text-gray-500") if level.blank?

    tag.span(class: "pill bg-gray-100 text-gray-700") do
      safe_join([ tag.span("", class: "w-1.5 h-1.5 rounded-full #{RISK_DOT.fetch(level, 'bg-gray-400')}"), level.humanize ])
    end
  end

  # A larger, chip-free risk readout for stat blocks: coloured dot + level word.
  def risk_indicator(level)
    return tag.span("Unscored", class: "text-base font-semibold text-gray-400") if level.blank?

    tag.span(class: "inline-flex items-center gap-2 text-base font-semibold text-gray-900") do
      safe_join([ tag.span("", class: "w-2.5 h-2.5 rounded-full #{RISK_DOT.fetch(level, 'bg-gray-400')}"), level.humanize ])
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

  # One labelled row on an asset detail page.
  def detail_row(label, value = nil, &block)
    content = block ? capture(&block) : value
    content = "—" if content.blank?
    tag.div(class: "px-5 py-2.5 grid grid-cols-3 gap-4") do
      tag.dt(label, class: "text-sm text-gray-500") +
        tag.dd(content, class: "col-span-2 text-sm text-gray-900")
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
