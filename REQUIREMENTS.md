# compliventory — Requirements

## Vision

1. **Source of truth** for all vendors and systems (assets) used across the company.
2. Platform for **vendor assessment, RoPA (GDPR Art. 30)** and other compliance records — the key system for the compliance team.
3. **Any employee** can submit a new vendor/system or propose changes to an existing one; every change goes through **approval by the system owner**.

Companion product to governauthzer (systems registered here can later feed governauthzer's application catalog via API), but deliberately a separate product, not a module.

## Priorities

- **MVP = the inventory (source of truth).** Assessment and RoPA come later.
- The first version must be **maximally simple, convenient, and pleasant to use**.

## MVP scope

- **Vendors & systems**: create and edit both. One vendor can own multiple systems.
- **Change proposals with approval**: convenient review UI for proposed changes; approve or reject each proposal. See "Change control" below for who approves what.
- **Audit log.**
- **Dynamic asset tables**: search/filter support, every column sortable, user-selectable set of visible columns.
- **Users/employees without in-app CRUD** — same model as governauthzer (no manual user creation in the UI; users arrive via sync/API, bootstrap seed is the only carve-out).
- **Auth via OIDC** — same approach as governauthzer, including the developer variant (`/dev/sign-in` dev-only session form working off seed data, no IdP required locally).

## Change control (decided 2026-07-19)

Three approval lanes:

| Change | Who approves |
|---|---|
| New vendor or system submission | **Compliance team** |
| Edit to a **compliance-controlled field** (any editor, incl. the owner) | **Compliance team** |
| Edit to a regular field by a non-owner | **System owner** (or delegate) |
| Edit to a regular field by the owner/delegate | Applied immediately, no approval |

Compliance-controlled fields are the ones that directly affect vendor assessment / RoPA (marked ⚖ in the field lists below). The set is fixed per entity type in MVP (no admin UI for configuring which fields are gated — keep it simple; revisit later).

## Ownership model (confirmed 2026-07-19)

The real-world problem: a system's accountable person (business owner) is often a top manager who never touches the tool; edits and approvals are actually done by an assistant.

Proposal — split **accountability** from **operation** (RACI: accountable vs responsible):

- **Business owner** — exactly one user per system. The named accountable person; appears in reports, future assessments and RoPA. Not required to ever log in.
- **Delegates** — zero or more users per system. Have the same powers as the owner inside compliventory: edit regular fields directly, approve/reject proposals from other employees. Every action is audit-logged with the *actual* actor, so the trail always shows "approved by <delegate> on behalf of owner <owner>".

This matches industry practice (Vanta/Drata/Torii all model business owner + security/IT owner + contacts as separate roles). Rejected alternatives: owner-only approval (top managers become a bottleneck and the tool dies); team-as-owner (blurs accountability — assessments and RoPA need one named accountable person).

**Vendors use the same owner + delegates mechanics as systems** (confirmed 2026-07-19).

Compliance team is a global role (not per-system).

## Data model — MVP field set (decided 2026-07-19, research-based)

Sources: Vanta/Drata/OneTrust vendor records, ISO 27001 A.5.9 asset-register practice, ICO/EDPB Art. 30 RoPA field models, SaaS-inventory tools (Torii, Zylo). Fields marked **⚖** are compliance-controlled (see Change control).

### Vendor

| Field | Type | Notes |
|---|---|---|
| name | string, unique, required | |
| website | url | |
| description / services provided | text | what we use them for |
| category | picklist | SaaS, infrastructure/cloud, professional services, software, other |
| status | enum | lifecycle: `pending_approval → active → offboarded`; `archived` |
| owner | user ref | relationship/business owner |
| delegates | user refs | see Ownership model |
| vendor contact | name + email | contact on the vendor's side |
| ⚖ processes personal data | boolean | forward-compat with RoPA/assessment |
| ⚖ data location | picklist | EU / US / other (+ free text) |
| ⚖ risk tier | enum | low / medium / high / critical; **set by compliance only** (not proposable) |
| notes | text | |

### System

| Field | Type | Notes |
|---|---|---|
| name | string, unique, required | |
| vendor | ref, optional | optional — internal/in-house systems have no vendor |
| description / purpose | text | |
| status | enum | `pending_approval → active → deprecated → retired` |
| business owner | user ref, required | see Ownership model |
| delegates | user refs | |
| technical owner | user ref, optional | IT/engineering counterpart |
| department / business unit | picklist | |
| url | url | where the system lives |
| authentication method | picklist | SSO/OIDC, password+MFA, password, other — cheap to capture, valuable for assessment |
| ⚖ criticality | enum | low / medium / high / critical |
| ⚖ data classification | enum | public / internal / confidential / restricted |
| ⚖ stores personal data | boolean | |
| ⚖ personal data categories | multi-picklist | employees / customers / special categories… (RoPA seed) |
| notes | text | |

### Deliberately deferred (post-MVP)

Contract value & renewal dates, license/seat counts, password-policy details, security-review scheduling (review status, next review deadline), subprocessor registry, DPA/document attachments, RoPA processing activities as first-class records, custom fields. All present in mature tools; all cut to keep MVP simple. The ⚖ fields above are chosen so the assessment/RoPA phase can build on them without migration pain.

## Out of MVP (later phases)

- Vendor assessment workflows
- RoPA and other compliance records
- Sync of systems into governauthzer via API

## Stack

Same as governauthzer (stack is not a hard requirement, but preferred):

- Rails 8.1 + PostgreSQL 16
- Hotwire (Turbo + Stimulus) + importmaps, Tailwind v4
- Solid Queue / Cache / Cable
- Minitest
- UUID primary keys
- Plain Ruby policy objects (no authz framework)

## Open questions

None — all resolved 2026-07-19. Design lives in `DESIGN.md`.
