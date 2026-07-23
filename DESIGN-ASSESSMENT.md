# compliventory — Vendor Risk Assessment Design

Status: draft v1, 2026-07-23. Companion to `DESIGN.md` / `REQUIREMENTS.md` ("post-MVP:
assessment"). Includes the implementation task list at the bottom.

## Research: how the market does it

### Vanta (TPRM module)

- **Inherent risk rubric**: configurable attributes (data sensitivity, access level,
  business criticality); score = *highest level among applicable attributes* (highest-wins,
  no weighted math). Output: Critical/High/Medium/Low/Unscored, auto-computed from vendor
  fields, manual override possible.
- **Assessment records** per type (Security, Privacy, AI, …), lifecycle
  `in progress → completed`; completed assessments are immutable.
- **Evidence collection** through a vendor-facing portal: questionnaires (builder with 4
  question types + conditional logic), document requests, reminder emails every 5 days,
  AI auto-fill of answers.
- **Recurrence**: assessment frequency driven by inherent risk tier; next assessment
  auto-starts ~30 days before due date.
- **Finalization**: assessor sets a **residual risk** score and a recommendation
  (Approved / Conditionally approved / Not approved).

### Drata (TPRM)

Same skeleton: vendor intake → questionnaire templates → security review with linked
evidence → documented decision; recurring reviews by inherent risk; heavy AI push
(summarizing questionnaire answers, "agentic" evidence evaluation).

### SimpleRisk / Eramba (open-source GRC)

Risk-register-first (likelihood × impact matrices, treatment plans). Praised for
simplicity, criticized for manual upkeep, weak integration with the asset inventory, and
workflows that don't scale; the vendor-assessment part is bolted onto the register rather
than onto the inventory.

### What practitioners actually complain about

- **Questionnaires are largely security theater**: generic 300+ question sheets, vendor
  fatigue, unvalidated self-reported answers, no connection to ongoing monitoring.
  Industry counter-trend: *review the vendor's existing artifacts* (SOC 2 report,
  ISO 27001 cert, DPA, pentest summary) instead of sending questionnaires; reserve custom
  questions for high-risk gaps.
- **Tracking is the real pain**: who is due for review, what was collected, what was
  decided — historically spreadsheets + email.
- **Rubric configurators are over-engineered** for small/mid companies: you configure a
  scoring model instead of assessing vendors.
- **Disconnect from the inventory**: risk factors (data classification, criticality,
  personal data) are re-asked inside the assessment even though the inventory already
  knows them.

## Our thesis: better and simpler

compliventory already *is* the inventory — the ⚖ fields are the risk factors. So:

1. **No vendor-facing anything in v1.** No questionnaire builder, no portal, no email
   round-trips with vendors. An assessment is an *internal review record* by the
   compliance team: what documents we reviewed, what we found, what we decided. This is
   what small companies actually do (SOC 2 review), minus the theater.
2. **Inherent risk is computed, not configured.** A fixed transparent rule over fields we
   already have (vendor's personal-data flags + linked systems' criticality and data
   classification), highest-wins like Vanta, shown with a "because of…" breakdown.
   No rubric admin UI.
3. **`risk_tier` gets a precise meaning: residual risk.** Today it's a free-floating
   compliance-set label. After this feature it is *set by completing an assessment*
   (still directly editable by compliance for corrections). Inherent = computed live;
   residual = decided at last assessment.
4. **Review cadence falls out of the tier.** Completing an assessment stamps
   `next_review_on` (suggested by tier, overridable). Due/overdue reviews surface in
   `/compliance` and the vendors table — the tracking problem is solved by the inventory
   itself, not a separate calendar.
5. **Immutable records, existing philosophy.** In-progress assessment rows are mutable
   working state; completed ones are frozen compliance records (kept, unlike proposals —
   they're the deliverable). Cancel destroys the row and audits the snapshot, exactly
   like asset rejection.

Explicitly **not building** (v1): questionnaires/vendor portal, weighted scoring, risk
register (likelihood × impact), system assessments (schema leaves the door open),
AI review helpers, auto-started assessments.

## Data model

### assessments

```ruby
create_table :assessments, id: :uuid do |t|
  t.references :asset, polymorphic: true, type: :uuid, null: false  # Vendor only in v1
  t.references :assessor, type: :uuid, null: false, foreign_key: { to_table: :users }
  t.string :status, null: false, default: "in_progress"  # in_progress | completed
  # snapshot at start (computed then frozen):
  t.string :inherent_risk                                # low|medium|high|critical|nil (unscored)
  t.jsonb :inherent_risk_factors, null: false, default: []  # [{factor:, value:, level:}]
  # working surface:
  t.jsonb :evidence, null: false, default: []            # see Evidence checklist below
  t.text :summary                                        # findings / notes, free text
  # set on completion:
  t.string :residual_risk                                # low | medium | high | critical
  t.string :decision                                     # approved | approved_with_conditions | rejected
  t.text :conditions                                     # required when approved_with_conditions
  t.date :next_review_on
  t.datetime :completed_at
  t.timestamps
end
add_index :assessments, [:asset_type, :asset_id]
add_index :assessments, [:asset_type, :asset_id],
          unique: true, where: "status = 'in_progress'",
          name: "index_assessments_one_in_progress_per_asset"
```

Model constants: `STATUSES`, `RISK_LEVELS = %w[low medium high critical]`,
`DECISIONS = %w[approved approved_with_conditions rejected]`,
`EVIDENCE_KINDS` (below). Completed assessments reject any attribute change
(`errors.add(:base, ...)` in a `before_save` guard when `status_was == "completed"`).

### vendors — two denormalized columns

```ruby
add_column :vendors, :last_assessed_on, :date
add_column :vendors, :next_review_on, :date
```

Maintained only by `Assessments::Completer`. Denormalized so the dynamic vendors table
sorts/filters on them without joins (AssetTable is column-driven). Both are *not* in
`EDITABLE_FIELDS` — they change only via assessment completion (compliance can re-run an
assessment to move them; no hand-editing).

### Evidence checklist (jsonb, no extra table)

`evidence` is an array of items, one per document kind, initialized at start from
`EVIDENCE_KINDS`:

```ruby
EVIDENCE_KINDS = %w[soc2_report iso27001_cert dpa security_page pentest_summary other].freeze
# item: { "kind" => "soc2_report", "state" => "pending", "url" => nil, "notes" => nil }
# states: pending | reviewed | not_applicable
```

Assessor flips states, pastes links (to the doc in Drive/the vendor's trust page), adds
notes, while `in_progress`. Completion does **not** require all items resolved (leaving
`pending` items is itself a finding) — but the completion screen shows unresolved counts.
File uploads are a separate cuttable task (ActiveStorage, whole-assessment level).

## Inherent risk scoring — fixed rule

`Assessments::InherentRisk.call(vendor)` → `{ level:, factors: [...] }`. Pure function,
no persistence. Only `active`/`deprecated` linked systems count. Highest level wins:

| Factor | Condition | Level |
|---|---|---|
| system data classification | any linked system `restricted` | critical |
| | any linked system `confidential` | high |
| system criticality | any linked system `critical` | critical |
| | any linked system `high` | high |
| special-category personal data | any linked system's `personal_data_categories` includes `special_categories` | high |
| personal data | `vendor.processes_personal_data` or any linked system `stores_personal_data` | medium |
| data location | `vendor.data_location == "other"` | medium |
| infrastructure vendor | `vendor.category == "cloud_infra"` | medium |
| baseline | any factor known but none matched | low |

**Unscored** (`level: nil`) when nothing is known: `processes_personal_data` is nil *and*
no linked system has any ⚖ field set. `factors` lists every matched row (factor key,
observed value, contributed level) so the UI can render "high — because System X is
confidential". Order factors by contributed level desc.

### Suggested review cadence (by residual risk)

critical → 6 months, high → 12, medium → 24, low → 36. Constant
`Assessment::REVIEW_MONTHS = { "critical" => 6, "high" => 12, "medium" => 24, "low" => 36 }`.
Pre-fills `next_review_on` on the completion form; assessor may override.

## Services, policy, audit

Follows the existing `Assets::*` / `Proposals::*` service pattern (each audits in the
same transaction):

- `Assessments::Starter.call(vendor:, actor:)` — guards: compliance actor, vendor not
  `pending_approval`, no in-progress assessment. Snapshots inherent risk + factors,
  initializes `evidence`. Audit: `assessment.started`.
- `Assessments::Updater.call(assessment:, actor:, params:)` — in-progress only; updates
  `evidence` items and `summary`. No audit per keystroke (working state; the completed
  record is the audit artifact).
- `Assessments::Completer.call(assessment:, actor:, params:)` — requires `residual_risk`,
  `decision`, `next_review_on` (`conditions` iff `approved_with_conditions`). In one
  transaction: sets completion fields + `completed_at`, updates vendor
  `risk_tier = residual_risk`, `last_assessed_on = today`, `next_review_on`. Audit:
  `assessment.completed` with `attribute_changes` covering the vendor's risk_tier change.
- `Assessments::Canceller.call(assessment:, actor:)` — in-progress only; audit
  `assessment.cancelled` with full snapshot in `targets` (same pattern as asset
  rejection), then destroy.

`AssessmentPolicy` (POPO like the others): `may_assess?` / `may_edit?(assessment)` /
`may_complete?` / `may_cancel?` — all "actor is compliance"; view is open to everyone
(transparency, as with the rest of the app).

New audit event types: `assessment.started/completed/cancelled`.

## UI map

| Route | What |
|---|---|
| `/vendors/:id` | new **Risk** panel: computed inherent risk + factor breakdown, `risk_tier` (residual) with "assessed on … / next review …", assessment history links, "Start assessment" button (compliance, when allowed) |
| `/vendors/:vendor_id/assessments/:id` | the assessment page: in-progress = editable checklist (Turbo inline updates) + summary + Complete/Cancel; completed = read-only record |
| `/compliance` | new **Assessments** section: in-progress (mine), overdue (`next_review_on <= today`), never assessed (active vendors, no completed assessment) |
| `/vendors` table | new columns `risk_tier` exists already; add `last_assessed_on`, `next_review_on` (sortable), filter "review status" (overdue / due in 30d / never assessed / ok) |

Completion is a form section on the assessment page (residual pre-filled with the
snapshot inherent level, `next_review_on` pre-filled by cadence table), not a separate
route.

Email (reuse ActionMailer setup): weekly digest to compliance users of overdue +
never-assessed active vendors (Solid Queue recurring job, skip when empty). Vendor owner
gets a note when an assessment of their vendor completes.

---

## Implementation tasks

Ordered; each lands green (`bin/rails test` + rubocop) before the next. Every task names
the pattern file to imitate — follow it closely.

### Task 1 — Schema + Assessment model

Migration(s): `assessments` table and the two vendor columns exactly as in "Data model"
above (including the partial unique index). `Assessment` model: constants (`STATUSES`,
`RISK_LEVELS`, `DECISIONS`, `EVIDENCE_KINDS`, `REVIEW_MONTHS`), `belongs_to :asset,
polymorphic: true`, `belongs_to :assessor, class_name: "User"`, inclusion validations
(`allow_nil` for completion fields), `conditions` presence iff decision is
`approved_with_conditions`, completed-record immutability guard, scopes `in_progress`,
`completed`, `for_asset(asset)`. `Vendor: has_many :assessments, as: :asset`. Pattern:
`app/models/change_proposal.rb` + `app/models/vendor.rb`. Tests: model validations,
immutability guard, partial-index uniqueness (`test/models/`).

### Task 2 — `Assessments::InherentRisk` scorer

`app/services/assessments/inherent_risk.rb`, pure `call(vendor)` returning
`{ level:, factors: }` per the fixed rule table (implement the table literally; only
active/deprecated systems count; unscored condition as specified). Pattern:
`app/services/application_service.rb`. Exhaustive unit tests: one per table row, a
highest-wins combination case, unscored case, factor ordering.

### Task 3 — Lifecycle services + policy + audit

`Assessments::Starter/Updater/Completer/Canceller` and `AssessmentPolicy` exactly as in
"Services, policy, audit". Patterns: `app/services/assets/approver.rb` (transaction +
audit), `app/services/assets/rejecter.rb` (snapshot-then-destroy for Canceller),
`app/policies/` for the policy. Register the three event types wherever existing
`vendor.*` types are handled (audit viewer labels). Tests: service tests covering guards
(non-compliance actor, second in-progress, completing without residual/decision, vendor
side-effects on completion incl. `risk_tier`), policy tests.

### Task 4 — Assessment pages + vendor Risk panel

Routes: `resources :assessments, only: [:show, :create, :update, :destroy]` nested under
vendors, plus a `complete` member action (`PATCH`). Controller enforces
`AssessmentPolicy` and delegates to the services. Views: assessment page (in-progress:
evidence checklist rows with state select + url + notes, Turbo-frame per row saving via
`Updater`; summary textarea; Complete section with pre-filled residual/next_review_on;
Cancel button with confirm) and completed read-only rendering of the same record; vendor
detail Risk panel per "UI map" (inherent breakdown rendered from live
`InherentRisk.call`, history list, Start button). Pattern: proposal review UI
(`app/views/proposals/`, `app/controllers/proposals_controller.rb`) and vendor detail
(`app/views/vendors/show.html.erb`). Controller/system tests: start→edit→complete happy
path, cancel, non-compliance gets no buttons and 403 on POST, completed page has no forms.

### Task 5 — Surfacing: /compliance section + vendors table

(1) `/compliance`: "Assessments" section per "UI map" (three lists; overdue and
never-assessed are queries on vendors: `next_review_on <= today`, and `active` with
`last_assessed_on IS NULL`). Pattern: `app/controllers/compliance_controller.rb` +
its view. (2) Vendors table: add `last_assessed_on`, `next_review_on` columns (sortable,
not default-visible) and a "review status" select filter (overdue / due in 30 days /
never assessed / ok) to the vendors `AssetTable` config. Pattern: existing column/filter
definitions in the vendors table config. Tests: filter queries, section rendering.

### Task 6 — Email notifications

`AssessmentMailer`: (a) weekly compliance digest listing overdue + never-assessed active
vendors — Solid Queue recurring job (`config/recurring.yml`), skip send when both lists
empty, one email per compliance user; (b) `completed` notice to the vendor's owner
(skip when owner is the assessor). Pattern: existing proposal/decision mailers and their
job wiring. Tests: mailer tests + job test for the empty-skip.

### Task 7 (cuttable) — File attachments

`has_many_attached :documents` on Assessment (whole-assessment, not per checklist item).
Upload/delete only while in-progress (policy + controller guard); listed on both
in-progress and completed views; direct download. Content-type allowlist (pdf, png, jpg,
docx, xlsx), 20 MB cap. Tests: upload guard on completed assessment.

### Task 8 — Seeds, demo, docs

Extend `db/seeds.rb` + demo data (`app/models/demo*`) with: one completed assessment
(with evidence links + residual set), one in-progress, one overdue vendor, one
never-assessed active vendor — so `/compliance` and the table filters demo well. Update
`docs/how-it-works.md` (new "Vendor risk assessments" section: lifecycle, inherent vs
residual, cadence table) and `docs/index.md` feature list. Keep README feature bullets in
sync.
