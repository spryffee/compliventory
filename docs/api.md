---
title: Users sync API
nav_order: 5
---

# Users sync API
{: .no_toc }

The HTTP contract your IdP / HR tooling integrates against.
{: .fs-6 .fw-300 }

1. TOC
{:toc}

---

## Canonical contract

The **authoritative** spec is the OpenAPI document in the repo:
[`openapi/v1.yaml`](https://github.com/spryffee/compliventory/blob/main/openapi/v1.yaml).
It is enforced against the application in CI via `committee-rails` — every request and
response is schema-checked, so drift fails the build. This page is an orientation, not a
duplicate; integrate against the YAML.

## The model: upsert by email

Users arrive in compliventory **exclusively** through this API (plus the seed bootstrap) —
there is no in-app user CRUD. The whole contract is upsert by email: POST a user on hire
or attribute change, set `active: false` on departure. There is deliberately **no
snapshot-and-diff sync** — compliventory only needs "these people exist and may log in /
be owners".

- `email` is the upsert key, matched case-insensitively, stored lowercase.
- `name` is a single full-name field; your directory is the source of truth.
- `role` is **not settable via sync** — roles are assigned in the admin UI.
- Deactivation (`"active": false`) blocks sign-in on the user's next request and removes
  them from owner pickers; history is kept.

## Authentication

Bearer token, minted in `/admin/api-tokens` (shown once, `cvt_` prefix, scope
`users:write`). Pass it in the `Authorization` header.

## Endpoints

### `POST /api/v1/users` — upsert

```sh
curl -X POST https://compliventory.example.com/api/v1/users \
  -H "Authorization: Bearer cvt_…" -H "Content-Type: application/json" \
  -d '{"email":"jane@corp.example","name":"Jane Doe","active":true}'
```

Returns the user (`201` on create, `200` on update).

### `GET /api/v1/users` — list

Full user list ordered by email. No pagination — this is a company directory, not a feed.

## Errors

All 4xx/5xx responses use one envelope; branch on the stable `error.code`
(`unauthorized`, `validation_failed`, …), not on the human-readable message:

```json
{ "error": { "code": "validation_failed", "message": "…", "details": { } } }
```

## Rate limits

Per-IP (600/min) and per-token (3000/min across all IPs) throttles guard `/api/v1`;
throttled requests get a `429` with the same error envelope and a `Retry-After` header.
Safelist your egress via `RATE_LIMIT_SAFELIST` if needed
([Deployment](deployment.md#environment-variables)).

## Audit attribution

Every audit event emitted during a token-authenticated request carries the token's
identity in its metadata — API writes are always attributable to a consumer.
