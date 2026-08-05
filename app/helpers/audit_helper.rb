# Rendering of audit events and change diffs — the audit log, per-asset trails,
# proposal cards and the diffs in mail bodies.
module AuditHelper
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
    when "owner_id", "technical_owner_id" then referenced_name(User, value)
    when "vendor_id"                      then referenced_name(Vendor, value)
    else audit_value(value)
    end
  end

  # A page of audit rows names the same few people over and over — two values per
  # diff, two diffs per row — so the lookup is memoized for the render. Misses are
  # cached too: a hard-deleted record must not be re-queried per mention.
  def referenced_name(klass, id)
    return audit_value(id) if id.blank?

    names = (@referenced_names ||= {})[klass.name] ||= {}
    names.fetch(id) { names[id] = klass.where(id: id).pick(:name) } || audit_value(id)
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
end
