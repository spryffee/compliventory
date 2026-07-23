module AssessmentsHelper
  EVIDENCE_KIND_LABELS = {
    "soc2_report" => "SOC 2 report",
    "iso27001_cert" => "ISO 27001 certificate",
    "dpa" => "Data processing agreement",
    "security_page" => "Security / trust page",
    "pentest_summary" => "Penetration test summary",
    "other" => "Other document"
  }.freeze

  FACTOR_LABELS = {
    "system_data_classification" => "System data classification",
    "system_criticality" => "System criticality",
    "special_category_personal_data" => "Special-category personal data",
    "personal_data" => "Personal data",
    "data_location" => "Data location outside EU/US",
    "infrastructure_vendor" => "Infrastructure vendor"
  }.freeze

  def evidence_kind_label(kind)
    EVIDENCE_KIND_LABELS.fetch(kind, kind.humanize)
  end

  def evidence_state_pill(state)
    dot = { "reviewed" => "bg-emerald-500", "not_applicable" => "bg-gray-400" }.fetch(state, "bg-amber-500")
    tag.span(class: "pill bg-gray-100 text-gray-700") do
      safe_join([ tag.span("", class: "w-1.5 h-1.5 rounded-full #{dot}"), state.humanize ])
    end
  end

  # One line of an inherent-risk factor breakdown, e.g.
  # "high — System data classification: confidential". The level pill sits in a
  # fixed-width column so the labels line up down the list.
  def factor_line(factor)
    label = FACTOR_LABELS.fetch(factor["factor"], factor["factor"].humanize)
    detail = factor["value"] == "present" ? label : "#{label}: #{factor['value'].humanize}"
    safe_join([
      tag.span(risk_pill(factor["level"]), class: "inline-flex w-20 shrink-0"),
      tag.span(detail, class: "text-sm text-gray-700")
    ])
  end

  # A next-review date, flagged red once it's due (today or past).
  def review_due_tag(date)
    return "—" if date.blank?

    text = date.strftime("%b %-d, %Y")
    if date <= Date.current
      tag.span("#{text} (overdue)", class: "text-red-600 font-medium")
    else
      tag.span(text)
    end
  end

  def decision_label(decision)
    return "—" if decision.blank?

    { "approved" => "Approved", "approved_with_conditions" => "Approved with conditions",
      "rejected" => "Rejected" }.fetch(decision, decision.humanize)
  end
end
