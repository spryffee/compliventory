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

### Changed

- The admin navbar no longer shows the signed-in user's name.

### Fixed

- The published image now carries the `service` label Kamal checks on pull. Deploying 0.1.0
  with Kamal failed at the pull step with *"Image … is missing the 'service' label"*.

## 0.1.0 — 2026-07-29

### Commits

- Update release.yml
- Revert "Release 0.1.0"
- Release 0.1.0
- Implement release flow
- Do not mention demo volume in quickstart
- Update docs
- Fix volume seeder
- Reduce number of pending proposals for demo
- Seed demo volume so the dynamic tables have something to do
- Sync docs with the current behaviour
- Stop repeating the vendor name in audit targets
- Render assessment outcomes in the audit log
- Fix digest nag
- Fix false being dropped as a blank field and 500 on vendor rejection
- Seed assessment demo data and document assessments
- Add assessment email notifications
- Surface assessments in compliance inbox and vendors table
- Redesign vendor risk panel
- Add assessment pages and vendor risk panel
- Add assessment lifecycle services and policy
- Add inherent risk scorer for vendors
- Add assessments schema and model
- Design assessment
- Fix privilege escalation: judge asset ownership by persisted owner_id
- Ignore blank-to-blank field no-ops when diffing asset edits
- Show owner/vendor names instead of ids in change diffs
- Add favicon to docs site
- Use per-destination .env.demo instead of a single prefixed .env
- Set dotenv approarch for secrets
- Add favicon
- Add public demo mode
- Fix flash placement
- Remove system tests from CI
- Add LICENSE
- Add docs site - Jekyll + Just the Docs on GitHub Pages
- Implement dynamic tables - declarative presenters, sort/filter/search, column picker in ui_preferences
- Implement change control - proposal lanes, decision services, inboxes, email notifications
- Implement inventory core
- implement auth + users - ENV OIDC, email matching, roles, sync API
- Rails 8.1 skeleton: UUID PKs, Tailwind component layer, CI, Postgres
- Add requirements and MVP design docs
- Initial commit

