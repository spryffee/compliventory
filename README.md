# compliventory

The company's vendors and systems, accounted for. A self-hosted inventory with
owner/compliance change control and an append-only audit log.

> **Early stage — inventory MVP.** Vendor assessment and GDPR records of
> processing (RoPA) are planned on top of this core.

## What it is

compliventory is the **source of truth** for what the company uses: vendors (every
third party) and systems (every application, vendor-backed or in-house), each with one
accountable owner plus delegates. Any employee can submit or propose changes; change
control routes every edit to the right reviewer — compliance for new entries and
compliance-gated (⚖) fields, the asset's owner for the rest — and everything lands in
an audit log. Companion app to
[governauthzer](https://github.com/governauthzer/governauthzer): compliventory owns the
asset catalog, governauthzer owns access decisions.

→ Full overview, concepts, API, and deployment docs: **[the docs site](https://spryffee.github.io/compliventory)**

## Quickstart (development)

Needs Ruby (per [`.ruby-version`](.ruby-version)) and PostgreSQL. A throwaway local DB:

```sh
docker run -d --name compliventory-pg -e POSTGRES_HOST_AUTH_METHOD=trust -p 5432:5432 postgres:16
bin/setup                 # bundle + db:prepare, then starts bin/dev
bin/rails db:seed         # demo data → open http://localhost:3000/dev/sign-in
```

## Documentation

- **[Docs site](https://spryffee.github.io/compliventory)** — how it works, getting
  started, admin guide, deployment.
- **[Users sync API](https://spryffee.github.io/compliventory/api.html)** — raw spec at
  [`openapi/v1.yaml`](openapi/v1.yaml), enforced in CI via committee.
- Docs source lives in [`docs/`](docs/) (Jekyll + Just the Docs, deployed to GitHub
  Pages by [`pages.yml`](.github/workflows/pages.yml)).

## License

TBD.
