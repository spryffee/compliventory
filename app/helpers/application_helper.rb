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

  # Raw before/after values in audit diffs — no humanizing, free text stays
  # verbatim; blank → ∅ so "cleared" is visible.
  def audit_value(value)
    case value
    when nil, "" then "∅"
    when Array   then value.empty? ? "∅" : value.join(", ")
    else value.to_s
    end
  end

  # A field's value in a change diff (proposals, audit trail, mailers). Reference
  # columns store UUIDs; resolve them to the referenced record's name so a diff
  # reads "Owner: Alice → Bob", not a pair of ids. Falls back to the raw id if
  # the record is gone (hard-deleted history), and to audit_value otherwise.
  def change_value(field, value)
    case field.to_s
    when "owner_id", "technical_owner_id"
      value.present? ? (User.find_by(id: value)&.name || audit_value(value)) : audit_value(value)
    when "vendor_id"
      value.present? ? (Vendor.find_by(id: value)&.name || audit_value(value)) : audit_value(value)
    else
      audit_value(value)
    end
  end

  # Events whose substance lives in metadata rather than a field diff. An
  # assessment's outcome IS the compliance fact, and the assigned risk tier is a
  # review result, not an edit — so it is shown as an assignment ("High", or
  # "High (was Medium)"), never as a "high → high" diff. Rendered per event type
  # on purpose: metadata is never dumped generically, it also carries internals
  # (snapshots, proposal_id, api_token_id).
  #
  # Returns [label, value] pairs; a nil label renders the value on its own.
  def audit_outcome(event)
    meta = event.metadata || {}
    case event.event_type
    when "assessment.completed" then assessment_outcome_lines(meta)
    when "assessment.started"   then [ [ "Inherent risk", risk_word(meta["inherent_risk"]) ] ]
    when "assessment.cancelled" then [ [ nil, "Abandoned — no outcome recorded" ] ]
    else []
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

  # A target descriptor from audit_events.targets — linked for the types that
  # have detail pages. An Assessment is nested under its vendor, so its route
  # needs the vendor id, which comes from the event's other target (assessment
  # events always carry both). Hard-deleted targets keep their display name; the
  # link may 404, which is the history-in-audit-log trade-off.
  def audit_target_tag(target, event)
    label = target["display"] || target["id"]
    case target["type"]
    when "Vendor" then audit_target_link(label, vendor_path(target["id"]))
    when "System" then audit_target_link(label, system_path(target["id"]))
    when "Assessment"
      vendor_id = event.target_id("Vendor")
      vendor_id ? audit_target_link(label, vendor_assessment_path(vendor_id, target["id"])) : tag.span(label)
    else tag.span(label)
    end
  end

  def audit_target_link(label, path)
    link_to label, path, class: "text-pine-700 hover:underline"
  end

  def audit_timestamp(time)
    tag.time(time.strftime("%b %-d, %Y %H:%M"), datetime: time.iso8601, title: time.iso8601, class: "whitespace-nowrap")
  end

  # Risk level for prose, not a chip. Blank → "Unscored" (matches risk_pill).
  def risk_word(level)
    level.presence&.humanize || "Unscored"
  end

  # `next_review_on` is stamped into metadata as a plain "YYYY-MM-DD" string;
  # anything unparseable is shown verbatim rather than swallowed.
  def audit_review_date(raw)
    return nil if raw.blank?
    Date.parse(raw).strftime("%b %-d, %Y")
  rescue Date::Error
    raw
  end

  # "High (was Medium)" only when the tier actually moved. A first assessment
  # (no previous tier) and a re-review that confirms the tier both read as a
  # plain assignment. Events recorded before `previous_risk_tier` existed simply
  # omit the parenthetical — the audit log is append-only, never backfilled.
  def assessment_outcome_lines(meta)
    residual = risk_word(meta["residual_risk"])
    previous = meta["previous_risk_tier"]
    residual = "#{residual} (was #{risk_word(previous)})" if previous.present? && previous != meta["residual_risk"]

    [
      [ "Residual risk", residual ],
      [ "Decision", meta["decision"]&.humanize ],
      [ "Next review", audit_review_date(meta["next_review_on"]) ]
    ].reject { |_, value| value.blank? }
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
