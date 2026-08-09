# Changelog

Notable changes per release. Format follows [Keep a Changelog](https://keepachangelog.com/);
versions follow [Semantic Versioning](https://semver.org/).


## Unreleased

### Upgrade notes

- Set `COMPLIVENTORY_HOST` and the three `OIDC_*` variables before deploying — the app now
  refuses to start without them, and says which are missing. `COMPLIVENTORY_HOST` must be an
  absolute URL. Neither applies with `DEMO_MODE`.
- If you set `BOOTSTRAP_ADMIN_EMAIL`, check it is a valid address: email format is now
  validated, and the seed that reads it runs on every boot.
- From here on a patch or minor release asks nothing of you — upgrading is a tag change.

### Fixed

- Notifications no longer fail when their record is decided before the mail goes out.
- The audit log no longer queries per changed field it shows.
- The weekly digest lists assessments left untouched for two weeks.
- The users sync API rejects malformed or non-string email and name values.
- An archived vendor no longer shows as up to date in the review-status filter.
- An edit saved on top of someone else's is refused.
- `/up` answers 503 when the database is unreachable.
- A vendor or system submits without touching the optional dropdowns.

### Changed

- Indexed the review queue and the tables' status filter.
- The app refuses to start when a required environment variable is missing or malformed.
- The demo persona picker is rate-limited per IP.

### Removed

- Active Storage and the unused image_processing gem, and libvips from the image.

### Security

- Every response carries a Content Security Policy.

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
