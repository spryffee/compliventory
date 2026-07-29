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

## 0.1.1 — 2026-07-29

### Changed

- The admin navbar no longer shows the signed-in user's name.

### Fixed

- The published image now carries the `service` label Kamal checks on pull. Deploying 0.1.0
  with Kamal failed at the pull step with *"Image … is missing the 'service' label"*.

### Commits

- Update changelog
- Do not show the signed-in user's name in admin navbar
- Label the image with the Kamal service name
- Deploy the demo from the published release image

## 0.1.0 — 2026-07-29

First release. Inventory of vendors and systems with two-lane change control,
vendor risk assessments, an append-only audit log, OIDC sign-in, and a users
sync API.
