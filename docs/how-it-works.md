---
title: How it works
nav_order: 2
---

# How it works
{: .no_toc }

The mental model, the objects, and the review loop — in plain language.
{: .fs-6 .fw-300 }

1. TOC
{:toc}

---

## The objects

**Vendors** are third parties the company relies on — a SaaS product, a cloud provider, a
services firm. **Systems** are applications in use; a system may belong to a vendor or be
in-house (no vendor). One vendor can own many systems.

Both carry a small, deliberate field set (name, description, category/department,
lifecycle status, contacts, notes) plus **compliance-gated fields** marked ⚖ throughout
the app — the ones that feed vendor assessment and GDPR RoPA later:

| Vendor ⚖ | System ⚖ |
|---|---|
| processes personal data | criticality |
| data location (EU / US / other) | data classification |
| risk tier *(set by compliance only)* | stores personal data |
| | personal data categories |

## Ownership: one owner, many delegates

Accountability and operation are split (RACI-style):

- **Business owner** — exactly one user per asset. The named accountable person, who may
  never log in (the real-world owner is often a top manager).
- **Delegates** — zero or more users with **identical in-app powers**: direct edits to
  regular fields, approve/reject on owner-lane proposals. The audit log always records
  the *actual* actor, so the trail shows who really clicked approve.

The compliance team is a **global role**, not per-asset.

## Change control: three lanes

Every write is routed by *what changed* and *who changed it*:

| Change | Who reviews |
|---|---|
| New vendor or system submission | **Compliance team** |
| Edit to a ⚖ field (any editor, incl. the owner) | **Compliance team** |
| Edit to a regular field by a non-owner | **Owner or delegate** |
| Edit to a regular field by the owner/delegate | Applied immediately |

Mechanics worth knowing:

- **New submissions are real records**, not proposals — they exist immediately with
  status `pending_approval` and appear in the tables. Approval flips them to `active`;
  rejection hard-deletes the record and leaves a full snapshot in the audit log.
- **Compliance edits apply immediately everywhere** — the approver's own edit is
  self-approved by definition.
- A single edit form serves everyone. On save, the app splits your changes by lane: what
  you may change directly is applied, the rest becomes one proposal per lane, each
  independently approvable.
- A proposal stores the values it was made against. If the record changed in the
  meantime, the review screen shows **base → current → proposed** — the reviewer decides;
  there is no hard conflict resolution.

## Where reviews happen

- **`/inbox`** — owner-lane proposals for assets you own or are delegated on.
- **`/compliance`** — compliance team only: pending submissions plus ⚖-field proposals.
- The **dashboard** surfaces both queues, your assets, and recent activity on them.

Reviewers are notified by email when a proposal is created; the proposer (and owner) are
notified of decisions.

## The audit log

Every write — create, edit, delegation change, decision — is recorded with actor, targets,
timestamp, field-level diff, justification, and correlation id. Records are **hard-deleted**
on rejection/offboarding cleanup; their history stays in the log (links from old audit
entries may 404 — that is the deliberate trade-off, history lives in the log, not in
soft-deleted rows).

Everyone signed in can read an asset's audit trail on its detail page; the global
viewer at `/audit` is compliance/admin only.

## Users and roles

There is **no in-app user CRUD**. Users arrive via the [sync API](api.md) from your IdP
or HR tooling; sign-in is OIDC with **email matching** (an unknown or deactivated email
is told to ask their admin — no just-in-time provisioning). Roles:

| Role | Adds |
|---|---|
| `member` | Read everything, submit and propose, own assets, decide owner-lane proposals on their assets |
| `compliance` | The compliance queue, ⚖ decisions, global audit viewer, immediate edits |
| `admin` | User roles, ownership repair, API tokens |
