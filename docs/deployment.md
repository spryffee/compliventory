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
| `SECRET_KEY_BASE` | — | **Required.** Signs session cookies. Any random string; generate one with `openssl rand -hex 64` and keep it — changing it signs everyone out. |
| `COMPLIVENTORY_HOST` | — | **Required.** Public base URL — used for the OIDC `redirect_uri` and links in emails. Must be absolute, e.g. `https://compliventory.example.com`. |
| `COMPLIVENTORY_DATABASE_HOST` | `localhost` | PostgreSQL host. |
| `COMPLIVENTORY_DATABASE_USER` | `compliventory` | DB role the app connects as. |
| `COMPLIVENTORY_DATABASE_PASSWORD` | — | DB password. |
| `OIDC_ISSUER` | — | **Required** unless `DEMO_MODE`. Your IdP's issuer URL (discovery-based). |
| `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` | — | **Required** unless `DEMO_MODE`. The OIDC client registered at your IdP. Redirect URI: `<COMPLIVENTORY_HOST>/auth/oidc/callback`. |
| `SMTP_ADDRESS` | — | SMTP host. **Unset ⇒ production mail is silently dropped** (the app works, nobody gets notified). |
| `SMTP_PORT` | `587` | |
| `SMTP_USER_NAME`, `SMTP_PASSWORD` | — | |
| `SMTP_AUTHENTICATION` | `plain` | |
| `MAIL_FROM` | `compliventory@localhost` | From-address for notifications. |
| `BOOTSTRAP_ADMIN_EMAIL` (+ `BOOTSTRAP_ADMIN_NAME`) | — | See [Bootstrap](#bootstrap-the-first-admin). |
| `DEMO_MODE` | `false` | Public demo: persona-picker sign-in + nightly data reset. See [Public demo mode](#public-demo-mode). |
| `DEMO_VOLUME` | `0` | Generated vendors seeded on top of the curated demo set, so the tables page and filter meaningfully. `0` disables it. Read at seed time, so the nightly reset rebuilds the same size. |
| `RATE_LIMIT_SAFELIST` | — | Comma-separated CIDRs exempt from rate limiting (corporate egress, monitoring). |
| `RAILS_LOG_LEVEL` | `info` | |
| `SOLID_QUEUE_IN_PUMA` | set by Kamal config | Run background jobs (email delivery) inside the web process — right for single-server installs. |

The app refuses to start if a **Required** variable above is missing or malformed, and
names all of them at once — a misconfigured deploy fails at rollout rather than at the
first sign-in. OIDC values are read per request, so changing them needs only a restart.

If the container dies at boot with *Missing `secret_key_base` … set this string with
`bin/rails credentials:edit`*, `SECRET_KEY_BASE` is unset. Ignore the advice in that message:
it points at an encrypted credentials file that ships inside the image but is not yours to
decrypt. `RAILS_MASTER_KEY` is never needed here.

## Releases

Every release publishes a multi-arch image (amd64 + arm64) to
`ghcr.io/spryffee/compliventory`. Pin the exact version in production. The version number is
an upgrade contract — what each bump obliges you to do is in
[CHANGELOG.md](https://github.com/spryffee/compliventory/blob/main/CHANGELOG.md).

## Install with Kamal (recommended)

[Kamal 2](https://kamal-deploy.org) gives you Let's Encrypt TLS, health-checked rollouts
with no downtime, and one-command rollback. It is how the public demo runs.

You do not need this repository — only a `config/deploy.yml` pointing at the published
image:

```yaml
service: compliventory
image: ghcr.io/spryffee/compliventory

servers:
  web:
    - 203.0.113.10

proxy:
  ssl: true
  host: compliventory.corp.example

registry:
  server: ghcr.io
  username: your-github-user
  password:
    - KAMAL_REGISTRY_PASSWORD     # a token with read:packages

env:
  clear:
    COMPLIVENTORY_HOST: https://compliventory.corp.example
    COMPLIVENTORY_DATABASE_HOST: compliventory-db
    COMPLIVENTORY_DATABASE_USER: compliventory
    SOLID_QUEUE_IN_PUMA: true
    OIDC_ISSUER: https://idp.corp.example
    OIDC_CLIENT_ID: compliventory
  secret:
    - SECRET_KEY_BASE
    - COMPLIVENTORY_DATABASE_PASSWORD
    - OIDC_CLIENT_SECRET

accessories:
  db:
    image: postgres:16
    host: 203.0.113.10
    port: "127.0.0.1:5432:5432"
    env:
      clear:
        POSTGRES_USER: compliventory
        POSTGRES_DB: compliventory_production
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data
```

Put the secrets in `.kamal/secrets` — `SECRET_KEY_BASE` is a random string you generate once
(`openssl rand -hex 64`); the other two come from your IdP and your database. Then:

```sh
kamal setup -P --version 0.2.0
```

`-P` (`--skip-push`) is what makes Kamal deploy the released image rather than build one
from your source, and `--version` picks the tag.

Leave `service:` as `compliventory`. Kamal refuses to deploy an image whose `service`
label doesn't match, and the published image is labelled for that name.

## Install with Docker Compose

Supported for when Kamal doesn't fit. You bring your own TLS-terminating proxy and accept
a few seconds of downtime per upgrade; in exchange there is one file and no control
machine. Take
[`compose.yaml`](https://github.com/spryffee/compliventory/blob/main/compose.yaml),
put the values in a `.env` beside it, and:

```sh
docker compose up -d
```

## Upgrading

Migrations run automatically when the container boots, so an upgrade is a tag change:

```sh
kamal deploy -P --version 0.2.0        # Kamal
docker compose pull && docker compose up -d   # Compose (pin the new tag first)
```

Read the release's **Upgrade notes** first — that is where anything you must do by hand
is written, and a major version means there is something.

One thing to know before you roll back: **the image goes back, the database does not.**
`kamal rollback` returns the previous container to a schema that has already been
migrated. Migrations within a major version are written to tolerate this (a release only
adds; removals wait for the next one), so stepping back one version is safe. Skipping
backwards across several is not — restore a database backup instead.

## Bootstrap the first admin

Fresh install, empty users table, and sign-in requires a synced user — the carve-out is
the seed task. Put the variables in the app's own environment (`env: clear:` for Kamal,
`environment:` for Compose):

```
BOOTSTRAP_ADMIN_EMAIL=you@corp.example
BOOTSTRAP_ADMIN_NAME=Your Name
```

On a first deploy that is all — `db:prepare` seeds while initialising the database. If the
app is already running, add them, redeploy, then run the seed task in the container:

```sh
kamal app exec 'bin/rails db:seed'           # Kamal
docker compose exec app bin/rails db:seed    # Compose
```

Idempotent: creates (or promotes) that one admin and nothing else in production. Then
sign in through your IdP, mint an API token in `/admin/api-tokens`, and sync the rest of
the users via the [API](api.md). Demo data seeds only in development or demo mode.

## Public demo mode

For a shareable "anyone with the link can play" instance, set `DEMO_MODE=true`. This
changes three things:

- **Sign-in** becomes a **persona picker** at `/demo/sign-in` (no IdP needed) — visitors
  enter as any seeded role (employee, owner, compliance, admin) and share one sandbox.
  `/login` redirects there. OIDC is not required.
- **A banner** on every page marks the instance as a shared sandbox that resets nightly.
- **A nightly reset** (`Demo::ResetJob`, 04:00, via Solid Queue recurring) wipes the whole
  domain and reseeds the demo dataset — undoing any edits, deletions, or minted tokens.

Set `DEMO_VOLUME` (see above) so the sandbox is big enough for the tables to paginate and
filter; the nightly reset regenerates the same data.

Keep SMTP unset so notification emails are dropped rather than delivered. Everything else
(rate limiting, the audit log, change-control lanes) works exactly as in production.

### Deploying the demo with Kamal

[`config/deploy.demo.yml`](https://github.com/spryffee/compliventory/blob/main/config/deploy.demo.yml)
is a ready-made destination: it sets `DEMO_MODE` and a Postgres accessory on the same box.
Your domain, server IP and DB password are **not committed** — they go in a gitignored
`.env.demo`, which the destination loads at deploy time:

```sh
cp .env.example .env.demo
$EDITOR .env.demo      # DOMAIN, SERVER_IP, SECRET_KEY_BASE, COMPLIVENTORY_DATABASE_PASSWORD
```

Then, with the registry filled in in `config/deploy.yml`:

```sh
kamal setup  -d demo -P --version 0.2.0   # provisions the DB accessory + app
kamal deploy -d demo -P --version 0.2.0   # from then on
```

Always pass `-P --version`. This destination points at the public GHCR package, so a plain
`kamal deploy -d demo` builds your working tree and pushes it there.

The demo dataset needs no separate step: `db:prepare` runs on boot and seeds it while
initialising the database, and the nightly job keeps it fresh from then on.

## Notes

- `/dev/sign-in` and the mail preview are **development-only routes** — they do not exist
  in production (404), independent of any controller guard. `/demo/sign-in` exists in
  production **only** when `DEMO_MODE=true`; otherwise it 404s.
- Sessions are 24-hour signed cookies; authorization is computed live per request, so
  deactivating a user via sync locks them out on their next request.
- The audit log is append-only at the application layer. Database-level protection
  (restricted DB roles) is a post-MVP concern; treat DB access as root access.
