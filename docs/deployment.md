---
title: Deployment
nav_order: 6
---

# Deployment
{: .no_toc }

Running compliventory in production: configuration, OIDC, mail, and bootstrap.
{: .fs-6 .fw-300 }

1. TOC
{:toc}

---

compliventory is self-hosted. Infrastructure choices (where Postgres lives, which SMTP
provider) are yours; the app follows 12-factor conventions — everything is environment
variables.

## Prerequisites

- **PostgreSQL** 13+ (16+ recommended). Uses `gen_random_uuid()`; no extensions needed.
- The Solid stack (Queue / Cache / Cable) runs **on Postgres** — production uses four
  databases (`primary` / `cache` / `queue` / `cable`), prepared by `db:prepare`.
- Ruby per [`.ruby-version`](https://github.com/spryffee/compliventory/blob/main/.ruby-version)
  — or just use the provided container image.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `RAILS_MASTER_KEY` | — | **Required.** Standard Rails credentials key (`config/master.key`). |
| `COMPLIVENTORY_HOST` | `http://localhost:3000` | Public base URL — used for the OIDC `redirect_uri` and links in emails. Set to your public URL. |
| `COMPLIVENTORY_DATABASE_HOST` | `localhost` | PostgreSQL host. |
| `COMPLIVENTORY_DATABASE_USER` | `compliventory` | DB role the app connects as. |
| `COMPLIVENTORY_DATABASE_PASSWORD` | — | DB password. |
| `OIDC_ISSUER` | — | Your IdP's issuer URL (discovery-based). With it unset, the SSO button is hidden and nobody can sign in — set it. |
| `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` | — | The OIDC client registered at your IdP. Redirect URI: `<COMPLIVENTORY_HOST>/auth/oidc/callback`. |
| `SMTP_ADDRESS` | — | SMTP host. **Unset ⇒ production mail is silently dropped** (the app works, nobody gets notified). |
| `SMTP_PORT` | `587` | |
| `SMTP_USER_NAME`, `SMTP_PASSWORD` | — | |
| `SMTP_AUTHENTICATION` | `plain` | |
| `MAIL_FROM` | `compliventory@localhost` | From-address for notifications. |
| `BOOTSTRAP_ADMIN_EMAIL` (+ `BOOTSTRAP_ADMIN_NAME`) | — | See [Bootstrap](#bootstrap-the-first-admin). |
| `RATE_LIMIT_SAFELIST` | — | Comma-separated CIDRs exempt from rate limiting (corporate egress, monitoring). |
| `RAILS_LOG_LEVEL` | `info` | |
| `SOLID_QUEUE_IN_PUMA` | set by Kamal config | Run background jobs (email delivery) inside the web process — right for single-server installs. |

OIDC configuration is read per request, so changing it needs only a restart, and an
unconfigured instance fails cleanly at sign-in rather than at boot.

## Container

The provided
[`Dockerfile`](https://github.com/spryffee/compliventory/blob/main/Dockerfile) is
production-ready (jemalloc, Thruster in front of Puma, non-root user; migrations run via
the entrypoint):

```sh
docker build -t compliventory .
docker run -d -p 80:80 \
  -e RAILS_MASTER_KEY=… \
  -e COMPLIVENTORY_HOST=https://compliventory.example.com \
  -e COMPLIVENTORY_DATABASE_HOST=… -e COMPLIVENTORY_DATABASE_PASSWORD=… \
  -e OIDC_ISSUER=… -e OIDC_CLIENT_ID=… -e OIDC_CLIENT_SECRET=… \
  compliventory
```

### Kamal

[`config/deploy.yml`](https://github.com/spryffee/compliventory/blob/main/config/deploy.yml)
is a standard Kamal 2 setup: point it at your server and registry, put
`RAILS_MASTER_KEY` in `.kamal/secrets`, add the ENV above, `kamal setup`. TLS comes from
Kamal's proxy (`proxy: ssl: true` + your hostname) or your own load balancer.

## Bootstrap the first admin

Fresh install, empty users table, and sign-in requires a synced user — the carve-out is
the seed task:

```sh
BOOTSTRAP_ADMIN_EMAIL=you@corp.example BOOTSTRAP_ADMIN_NAME="Your Name" bin/rails db:seed
```

Idempotent: creates (or promotes) that one admin and nothing else in production. Then
sign in through your IdP, mint an API token in `/admin/api-tokens`, and sync the rest of
the users via the [API](api.md). Demo data only ever seeds in development.

## Notes

- `/dev/sign-in` and the mail preview are **development-only routes** — they do not exist
  in production (404), independent of any controller guard.
- Sessions are 24-hour signed cookies; authorization is computed live per request, so
  deactivating a user via sync locks them out on their next request.
- The audit log is append-only at the application layer. Database-level protection
  (restricted DB roles) is a post-MVP concern; treat DB access as root access.
