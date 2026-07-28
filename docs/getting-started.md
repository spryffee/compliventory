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

Uses a development-only sign-in and demo data, so there is no OIDC or user sync to wire up
first. For a real install see [Deployment](deployment.md).

## Prerequisites

- **Ruby** (see [`.ruby-version`](https://github.com/spryffee/compliventory/blob/main/.ruby-version))
- **PostgreSQL** — a throwaway local one in Docker is fine:

  ```sh
  docker run -d --name compliventory-pg \
    -e POSTGRES_HOST_AUTH_METHOD=trust -p 5432:5432 postgres:16
  ```

## 1. Run it

```sh
bin/setup            # bundle + db:prepare, then starts bin/dev
bin/rails db:seed    # demo users, vendors, systems, proposals and assessments
```

The app is at **<http://localhost:3000>**.

The demo set is nine vendors — enough to follow the walkthrough below, too few to see the
tables paginate or filter. Set `DEMO_VOLUME` to generate more:

```sh
DEMO_VOLUME=400 bin/rails db:seed    # ≈400 vendors, 900 systems, 2000 audit events
```

## 2. Sign in

Open **<http://localhost:3000/dev/sign-in>** and pick a user — these routes do not exist in
production:

| User | Why sign in as them |
|---|---|
| `employee@example.com` | A plain member — submits and proposes |
| `owner@example.com` | Owns the demo assets — decides owner-lane proposals |
| `delegate@example.com` | Delegate on some assets — same powers as the owner there |
| `compliance@example.com` | The compliance team — approves submissions and ⚖ changes |
| `admin@example.com` | Roles and API tokens |

## 3. Click through the loop

1. **As `employee`** — *Vendors → New vendor*, submit one. It lands with status
   `pending approval`. Then open an asset you don't own (say *Acme Cloud*), hit *Edit* and
   change the description — on save it becomes a proposal for the owner.
2. **As `compliance`** — open */compliance* and approve your new vendor (it turns
   `active`) or reject it (hard delete, snapshot in the audit log).
3. **As `owner`** — open */inbox* and approve or reject the description change, optionally
   with a comment.
4. **As `compliance`, assess a vendor** — *Start assessment* in the **Risk** panel of any
   vendor. Mark evidence, then complete it with a residual risk and a decision: the
   vendor's risk tier and review dates update.
5. **Anywhere** — open an asset and scroll to **Activity**: every step above is there, with
   diffs and actors.

*Vendors* and *Systems* are searchable, filterable per column, sortable on every column,
and have a **Columns** picker saved to your user.

Outgoing mail is not sent in development — it opens in the browser at
**<http://localhost:3000/letter_opener>**.
