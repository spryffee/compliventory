---
title: Getting started
nav_order: 3
---

# Getting started
{: .no_toc }

Run it locally and click through the whole submit → review → approve loop in a few minutes.
{: .fs-6 .fw-300 }

1. TOC
{:toc}

---

This is the fastest way to *see how it works* (see [How it works](how-it-works.md) for the
concepts). It uses a development-only one-click sign-in and demo data, so you don't need
to wire up OIDC or user sync yet. For a real install, see [Deployment](deployment.md).

## Prerequisites

- **Ruby** (see [`.ruby-version`](https://github.com/spryffee/compliventory/blob/main/.ruby-version))
- **PostgreSQL** — a throwaway local one in Docker is fine:

  ```sh
  docker run -d --name compliventory-pg \
    -e POSTGRES_HOST_AUTH_METHOD=trust -p 5432:5432 postgres:16
  ```

## 1. Run it

```sh
bin/setup                 # bundle + db:prepare, then starts bin/dev
bin/rails db:seed         # demo users, vendors, systems, and a pending proposal
```

The app is now at **<http://localhost:3000>**.

## 2. Sign in

Open **<http://localhost:3000/dev/sign-in>** — a development-only page listing the demo
users for one-click sign-in (these routes don't exist in production):

| User | Why sign in as them |
|---|---|
| `employee@example.com` | A plain member — submits and proposes |
| `owner@example.com` | Owns the demo assets — decides owner-lane proposals |
| `delegate@example.com` | Delegate on some assets — same powers as the owner there |
| `compliance@example.com` | The compliance team — approves submissions and ⚖ changes |
| `admin@example.com` | Roles and API tokens |

## 3. Click through the loop

1. **As `employee`** — *Vendors → New vendor*, submit one. It lands with status
   `pending approval`. Then open an asset you don't own (say *Acme Cloud*), hit *Edit*,
   change the description — on save it becomes a proposal for the owner.
2. **As `compliance`** — the dashboard shows the queue; open */compliance*, approve your
   new vendor (it turns `active`) or reject it (hard delete, snapshot in the audit log).
3. **As `owner`** — the dashboard shows a proposal waiting; open */inbox*, approve or
   reject the description change, optionally with a comment.
4. **Anywhere** — open an asset's detail page and check the **audit trail** tab: every
   step you just did is there, with diffs and actors.

Emails sent along the way (new proposal, decisions, new submission) open in the browser
at **<http://localhost:3000/letter_opener>**.

## 4. Poke at the tables

*Vendors* and *Systems* are server-rendered dynamic tables: search, per-column filters,
every column sortable, and a **Columns** picker whose selection is saved to your user
(it follows you across devices).

## Next steps

- Operating it for real: [Admin guide](admin-guide.md), [Deployment](deployment.md).
- Feeding it users from your directory: [Users sync API](api.md).
