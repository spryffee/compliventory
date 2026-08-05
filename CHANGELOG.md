# Changelog

Notable changes per release. Format follows [Keep a Changelog](https://keepachangelog.com/);
versions follow [Semantic Versioning](https://semver.org/), read as an *upgrade contract*:

| Bump | What it means for you |
| --- | --- |
| **Patch** `0.1.1 → 0.1.2` | Fixes. Change the tag and redeploy. |
| **Minor** `0.1 → 0.2` | New features; migrations apply themselves on boot. Change the tag and redeploy. |
| **Major** `0 → 1` | **Manual steps required** — a renamed environment variable, a destructive migration, or an upgrade you must pass through in order. Always described under *Upgrade notes*. |

While the version is `0.x` the project is pre-1.0: minors may still carry upgrade
notes. Read them before deploying.

Anything a deployer must *do* goes under **Upgrade notes** in that version's section.

## Unreleased

### Fixed

- Notifications no longer fail when their record is decided before the mail goes out.
- The audit log no longer queries per changed field it shows.
- The weekly digest lists assessments left untouched for two weeks.

## 0.2.2 — 2026-08-04

### Fixed

- A vendor whose risk assessment is already under way no longer appears twice in the
  compliance inbox — once as in progress, once as review due. The weekly digest email
  always got this right; the screen now agrees with it.

## 0.2.1 — 2026-07-30

### Changed

- The vendors and systems toolbar is a row shorter: Columns and Full screen are right-aligned
  on the search row.
- The Kamal templates and docs ask for `SECRET_KEY_BASE` instead of `RAILS_MASTER_KEY`, which
  only the maintainer can supply. Nothing to do on an existing install.

### Fixed

- The `docker run` example in the `Dockerfile` header passed `RAILS_MASTER_KEY` and could
  never have worked.

## 0.2.0 — 2026-07-29

### Added

- **Full-screen tables.** A *Full screen* button on the vendors and systems tables drops the
  page chrome and gives the table the whole viewport — 100 rows per page instead of 25,
  denser rows, and the header row stays put while you scroll. Escape or *Exit full screen*
  leaves it. The choice is remembered per device (a cookie), not per account, so a big
  monitor and a laptop can differ.

### Changed

- Wide tables now scroll sideways with the name column frozen, instead of squeezing every
  column until the rows wrap onto three lines.

## 0.1.1 — 2026-07-29

### Changed

- The admin navbar no longer shows the signed-in user's name.

### Fixed

- The published image now carries the `service` label Kamal checks on pull. Deploying 0.1.0
  with Kamal failed at the pull step with *"Image … is missing the 'service' label"*.

## 0.1.0 — 2026-07-29

First release. Inventory of vendors and systems with two-lane change control,
vendor risk assessments, an append-only audit log, OIDC sign-in, and a users
sync API.
