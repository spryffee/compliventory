---
title: Admin guide
nav_order: 4
---

# Admin guide
{: .no_toc }

The operator's surface: roles, user lifecycle, and API tokens.
{: .fs-6 .fw-300 }

1. TOC
{:toc}

---

The **admin area** (`/admin`) is deliberately small — compliventory has no in-app user
CRUD and no per-field configuration. Admins see an **Admin** link in the top bar;
everyone else gets a 403.

## Roles

| Role | Adds |
|---|---|
| `member` | The default. Read everything, submit/propose, own assets and decide owner-lane proposals on them. |
| `compliance` | `/compliance` queue, ⚖-field decisions, immediate edits everywhere, global `/audit` viewer. |
| `admin` | `/admin`: role assignment, API tokens. Admins can also repair an asset's ownership (owner/delegates) — and only that; admin is an operational role, not a content role. |

Roles are assigned in **`/admin/users`** — a read-only user list with a role picker.
Nothing else about a user is editable there; identity comes from sync.

## User lifecycle

Users arrive **only** through the [sync API](api.md) (plus the one-off
[bootstrap seed](deployment.md#bootstrap-the-first-admin)). The contract is upsert by
email:

- **Hire / rename** — POST the user; matched case-insensitively by email.
- **Departure** — POST with `"active": false`. Deactivation blocks sign-in **on their
  next request** (sessions are checked live against the DB), removes them from owner
  pickers, and keeps all history.
- **Sign-in** is OIDC with email matching: an email that isn't synced (or is inactive)
  gets a "ask your admin to sync you" page. There is no just-in-time provisioning.

## API tokens

**`/admin/api-tokens`** mints bearer tokens for sync consumers:

- The plain token is shown **once**, at creation, with a `cvt_` prefix; only a SHA-256
  digest is stored.
- One scope exists at MVP: `users:write`.
- Every audit event emitted during a token-authenticated request carries the consumer's
  identity in its metadata, so API writes are attributable per consumer.
- Revoke by deleting the token; there is no rotation-in-place — mint a new one, switch
  the consumer, delete the old.

## The audit log

`/audit` (compliance + admin) is the global viewer — filter by event type and actor.
Every asset's detail page also shows its own trail, visible to everyone signed in.
Audit events are append-only and survive the records they describe; a rejected
submission's full snapshot lives in its rejection event.

## Rate limiting

The auth and API surfaces are throttled (per-IP and per-token) with a JSON 429 envelope.
Corporate egress or monitoring IPs can be safelisted via `RATE_LIMIT_SAFELIST` — see
[Deployment](deployment.md#environment-variables).
