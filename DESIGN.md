# compliventory — MVP Design

Status: draft v1, 2026-07-19. Companion to `REQUIREMENTS.md`.

## Shape of the app

A single Rails 8.1 monolith, structurally a slimmed-down governauthzer: server-rendered
Hotwire UI, PostgreSQL 16, UUID PKs, Solid Queue/Cache/Cable, Minitest, plain-Ruby policy
objects, Tailwind v4 with governauthzer's component layer (`.btn-*`, `.card`, `.panel`,
`.data-table`, `.pill`) ported over — same visual language, different accent if desired.

Everyone authenticated can **read everything** (it's an internal inventory; transparency is
the point). Write paths are governed by the change-control lanes below.

## Deliberate divergences from governauthzer

governauthzer's auth was built for an IGA that is itself the crown jewels. compliventory's
threat model is milder (internal inventory), so two simplifications:

1. **Single OIDC provider, ENV-configured** (`OIDC_ISSUER`, `OIDC_CLIENT_ID`,
   `OIDC_CLIENT_SECRET`) instead of multi-IdP DB-backed config with admin UI. A company has
   one corporate IdP. Door open: the `omniauth_openid_connect` strategy is the same; moving
   to DB-backed providers later is additive.
2. **Email matching instead of STRICT subject pre-linking.** OIDC callback looks up the user
   by verified `email` claim from the trusted corporate IdP. No JIT creation — unknown email
   gets a friendly "ask your admin to sync you" page. Rationale: STRICT requires
   pre-provisioned `(provider, subject)` pairs, which is operational drag with no matching
   threat here; the IdP is singular and corporate-controlled.

Kept from governauthzer: no in-app user CRUD (sync API + seed only), `/dev/sign-in`
(dev-env-only session form over seed data), audit-event design verbatim, hard-delete with
history-in-audit-log philosophy, no JIT, Rack::Attack on auth + API routes.

Deferred, not designed: emergency-login CLI (production lockout → `rails console` for now).

## Data model

### users

```ruby
create_table :users, id: :uuid do |t|
  t.string :email, null: false
  t.string :name, null: false
  t.string :role, null: false, default: "member"   # member | compliance | admin
  t.boolean :active, null: false, default: true
  t.jsonb :ui_preferences, null: false, default: {}  # table column selections etc.
  t.timestamps
end
add_index :users, :email, unique: true
```

- `member` — everyone; can view all, submit proposals, own assets.
- `compliance` — plus: approves compliance-lane items; direct edits everywhere (an
  approver's own edit is self-approved by definition — applies immediately, audited).
- `admin` — plus: manages user roles and API tokens. (Compliance ⊄ admin and vice versa;
  a user table this small doesn't need a matrix.)
- No user state machine; `active: false` blocks login and removes from owner pickers,
  nothing else. Set via sync API.

### vendors

```ruby
create_table :vendors, id: :uuid do |t|
  t.string :name, null: false
  t.string :website
  t.text :description                    # what we use them for
  t.string :category                     # saas | cloud_infra | software | services | other
  t.string :status, null: false, default: "pending_approval"
                                         # pending_approval | active | offboarded | archived
  t.references :owner, type: :uuid, null: false, foreign_key: { to_table: :users }
  t.string :contact_name
  t.string :contact_email
  t.text :notes
  # compliance-controlled (⚖)
  t.boolean :processes_personal_data
  t.string :data_location                # eu | us | other
  t.string :risk_tier                    # low | medium | high | critical — compliance sets, not proposable
  t.timestamps
end
add_index :vendors, :name, unique: true
```

### systems

```ruby
create_table :systems, id: :uuid do |t|
  t.string :name, null: false
  t.references :vendor, type: :uuid, foreign_key: true   # nullable — internal systems
  t.text :description
  t.string :status, null: false, default: "pending_approval"
                                         # pending_approval | active | deprecated | retired
  t.references :owner, type: :uuid, null: false, foreign_key: { to_table: :users }
  t.references :technical_owner, type: :uuid, foreign_key: { to_table: :users }
  t.string :department
  t.string :url
  t.string :authentication_method        # sso | password_mfa | password | other
  t.text :notes
  # compliance-controlled (⚖)
  t.string :criticality                  # low | medium | high | critical
  t.string :data_classification          # public | internal | confidential | restricted
  t.boolean :stores_personal_data
  t.string :personal_data_categories, array: true, default: []
  t.timestamps
end
add_index :systems, :name, unique: true
```

Enum-ish strings validated in the model, not DB CHECKs (governauthzer convention — free for
an internal tool to extend). Each model declares its gated set:
`COMPLIANCE_FIELDS = %i[processes_personal_data data_location risk_tier]` /
`%i[criticality data_classification stores_personal_data personal_data_categories]`.

### delegations

```ruby
create_table :delegations, id: :uuid do |t|
  t.references :asset, polymorphic: true, type: :uuid, null: false  # Vendor | System
  t.references :user, type: :uuid, null: false, foreign_key: true
  t.timestamps
end
add_index :delegations, [:asset_type, :asset_id, :user_id], unique: true
```

One polymorphic table; vendors and systems share mechanics (confirmed). Owner + delegates
are functionally equal in-app; `owner_id` is the accountability pointer.

### change_proposals

```ruby
create_table :change_proposals, id: :uuid do |t|
  t.references :asset, polymorphic: true, type: :uuid, null: false
  t.references :proposer, type: :uuid, null: false, foreign_key: { to_table: :users }
  t.string :lane, null: false            # "owner" | "compliance"
  t.jsonb :attribute_changes, null: false # { "field" => [base_value, proposed_value] }
                                         # ("changes" would shadow ActiveModel::Dirty — same rename as audit_events)
  t.text :justification
  t.timestamps
end
add_index :change_proposals, [:asset_type, :asset_id]
add_index :change_proposals, :lane
```

- **Rows are pending by definition.** Approve/reject emits the audit event (full diff,
  decision, comment, actor) and **destroys the row** — governauthzer's
  state-in-row/history-in-audit-log philosophy.
- No `status` column, no decided_by/decided_at — all in the audit event.
- **New assets are not proposals.** A submission creates the real vendor/system row with
  `status: pending_approval`; the compliance inbox lists those rows directly. Reject →
  audit event with a full attribute snapshot in `targets`, then destroy. Approve →
  `status: active`. (One mechanism fewer; the row gets a real URL/id from day one.)

### audit_events, api_tokens

Copied from governauthzer's locked designs unchanged: `audit_events` (event-log shape,
`actor_*`, jsonb `targets` with display snapshots + GIN index, `changes`, `justification`,
`correlation_id`, single `AuditEvent.record!` write path; DB role separation is a
deployment-time option, not MVP code), `api_tokens` (SHA-256 digest, scopes — only
`users:write` needed at MVP).

Event types: `vendor.submitted/approved/rejected/updated`, `system.*` (same set),
`proposal.created/approved/rejected`, `delegation.added/removed`, `user.synced`,
`auth.login/dev_login`.

## Change-control mechanics

One edit form for everything; the service layer routes by field lane and actor:

```
Editor saves a diff
  ├─ actor is compliance ──────────────→ apply all, audit
  ├─ ⚖ fields in diff ────────────────→ change_proposal(lane: compliance)
  └─ regular fields in diff
       ├─ actor is owner/delegate ────→ apply, audit
       └─ otherwise ──────────────────→ change_proposal(lane: owner)
```

- A mixed edit by a non-owner produces **two proposals** (one per lane), each approvable
  independently. The form tells the editor what will happen before they save
  ("2 fields apply immediately, 1 goes to compliance review").
- `risk_tier` is compliance-set only: not editable in the form for non-compliance users at
  all (not even proposable) — per REQUIREMENTS.md.
- `owner` and delegates are regular fields: owner/delegate can transfer ownership and manage
  delegates directly; anyone else's suggestion goes through the owner lane. Admin/compliance
  can fix ownership directly (offboarded employees etc.).
- Status transitions after activation are regular fields (owner retires their system).
  `pending_approval → active` happens only via compliance approve.
- **Stale-base warning, no hard conflict resolution at MVP:** `changes` stores the base
  value; if the current value differs at review time, the approval screen shows
  base → current → proposed. Approving applies the proposed value.

Single service pair per asset (`Assets::Editor`, `Assets::Submitter`) + decision services
(`Proposals::Approver/Rejecter`, `Assets::Approver/Rejecter`), each emitting audit events
in the same transaction. Policies (POPO, governauthzer pattern): `VendorPolicy`,
`SystemPolicy`, `ProposalPolicy` answer `editable_directly?(field)`, `may_decide?` etc.

## Users sync API

Governauthzer-lite, spec-first OpenAPI + committee tests:

```
POST  /api/v1/users        # upsert by email: name, active
GET   /api/v1/users
```

Full snapshot-and-diff sync is **not** needed here — compliventory only needs "these people
exist and may log in / be owners". Upsert-by-email is the whole contract; deactivation is
`active: false` in the payload. If governauthzer is deployed alongside, a tiny bridge can
pump its user list in; otherwise HRIS/Google Workspace → this endpoint.

## UI map (MVP)

| Route | What |
|---|---|
| `/` | dashboard: my assets, my pending approvals, recent activity |
| `/vendors`, `/systems` | the dynamic tables |
| `/vendors/:id`, `/systems/:id` | detail: fields, owner/delegates, pending proposals, audit trail tab |
| `/vendors/:id/edit` etc. | one edit form, lane routing on save |
| `/vendors/new`, `/systems/new` | submission forms (any member) |
| `/inbox` | approvals for me: owner-lane proposals for my assets (+ delegations) |
| `/compliance` | compliance inbox: pending_approval assets + compliance-lane proposals |
| `/audit` | audit viewer (compliance + admin), filters as in governauthzer |
| `/admin/users` | read-only list + role picker (admin); no create/delete |
| `/admin/api-tokens` | token CRUD (admin) |
| `/dev/sign-in` | dev only |

### Dynamic tables

Server-side everything, no JS grid library:

- **Sort:** every column; `?sort=name&dir=desc` validated against a per-table allowlist.
- **Filter:** text search (ILIKE over name/description) + per-column selects (status,
  category, criticality, owner…) as query params; filter bar built once, shared by both tables.
- **Column picker:** a Stimulus-driven dropdown; selection persisted to
  `users.ui_preferences["vendors_table_columns"]` via a small endpoint, server renders only
  chosen columns. Cross-device, no flash-of-hidden-columns.
- **Pagination:** Pagy.
- Table config is declarative per asset type (column key → label, sort expr, filter type,
  default-visible) — one `AssetTable` presenter, two configs.

## Build phases

1. **Skeleton** — rails new (same generator flags as governauthzer), Tailwind component
   layer port, CI (rubocop + brakeman + test), Postgres container, seeds.
2. **Auth + users** — ENV OIDC + email matching, `/dev/sign-in`, sessions, roles,
   users sync API + api_tokens, Rack::Attack.
3. **Inventory core** — vendors/systems/delegations CRUD for owner/delegate/compliance
   direct paths, audit log + viewer, detail pages. (App is already useful here.)
4. **Change control** — proposal service + lanes, submission flow with pending_approval,
   inboxes (`/inbox`, `/compliance`), email notifications (ActionMailer, SMTP via ENV).
5. **Tables & polish** — sorting/filtering/column picker, dashboard, empty states,
   seed demo data, README + deploy notes (Dockerfile, Kamal, governauthzer-style).

Each phase lands green (tests + rubocop) before the next starts.

## Open design questions

- None blocking. Two to revisit during build: (a) email notifications scope at MVP
  (proposer notified on decision? owner notified on new proposal? — assume both, cheap);
  (b) whether `archived` vendor status is needed at MVP or `offboarded` suffices.
