# Cosmos Press Route Ownership

Status: accepted (2026-11-08). Local implementation is being superseded by the owner-approved
2026-11-10 local-surface hard reset.

> **Disposition (2026-11-10):** The earlier deferred instruction to remove `edit`, `info`, `news`,
> `help`, `docs`, and `guid` only after their consumers disappear is superseded: this repository's
> local routes/controllers are removed under the current hard-reset task. Its separate tool list is
> also amended: `rails_performance` is retired under the owner-approved Performance decision, while
> Mission, Flipper, Blazer, PgHero, Swagger, and Coverband remain operator tools. This spec does not
> authorize dropping database schemas/models, OIDC client registrations, redirect URIs, or existing
> persisted data; those remain subject to the model/database report and separate decisions.

The content subdomains `edit`, `info`, `news`, `help` and `docs` belong to
`umaxica-apps-cosmos-press`. This repository will stop drawing them and remove their controllers,
views and tests once nothing else uses that code.

Also decided on 2026-11-09 for all four repositories:

- `guid` is retired; this repository stops drawing it as well.
- This repository keeps and owns its own `.dev` operator tools (`mission`, `flipper`, `blazer`,
  `pghero`, `swagger`, `performance`, `coverband`), served on `<tool>-<repository>.umaxica.dev`
  (Sphere: `<tool>-sphere-jp.umaxica.dev`) as listed in `plans/2026-11-08-cloudflare-tunnel-split.md`.
  Access's settings are the reference for the other three repositories.

The full decision, observations, risks, acceptance and order are owned by the Press repository:
`specs/cosmos-press-route-ownership/spec.md` in `seahal/umaxica-apps-cosmos-press`.

Out of scope here: OIDC client registrations and redirect URIs, authentication and authorization
logic, database schemas, existing data and `config/database.yml` connections. Removing the
`publishing` connection is a separate later decision.

## Acceptance

- AC-1: This repository does not draw `edit`, `info`, `news`, `help`, `docs` or `guid`.
- AC-2: The application boots and its remaining test suite passes after the removal.
