Task (umaxica-apps-cosmos-governance only): implement the accepted pending registration design so
that App sign-up can complete in Governance. No commit. Never print secrets, key material, tokens or
environment values. Never edit config/credentials/*.yml.enc. Do not read .env contents. No push, no
deploy, no Cloudflare change, no change outside this repository. Ask before dropping databases or
volumes.

This container sees only this repository. Facts from Access are written below.

## Decision (owner; do not reopen)

- `adr/sign-up-finalization-in-auth.md`, section "Cosmos split amendment: Governance-owned pending
  registration", is accepted (2026-11-15) with owner items O-1 to O-6 decided as recommended (see
  "Owner decisions (2026-11-15)"). Read the whole section first; it is the specification.
- Evidence of the design: `evidence/2026-11-14-pending-registration-lifecycle-design-PRL4.md`.
- During sign-up, no server-side call between applications except reading the peer's JWKS. Every
  handoff (H1 to H6) is a browser GET through Jump.
- Terms: availability, ingress, eligibility, requirements (`adr/sign-flow-terminology.md` in Access;
  do not introduce sentry, guardrail or checkpoint).
- Scope: App realm (Client) sign-up only.

## Facts from Access (2026-11-15)

- Auth App origin `https://auth.umaxica.app`; its JWKS at `<origin>/.well-known/jwks.json`, PS256.
  Access does not yet issue H1, H3 or H5; it will implement them under its own order from the
  contract copied from this ADR. Until then, test with tokens signed by test keys through the public
  receivers.
- `sub` and `act` for a Client are `Client.public_id` (owner decision of 2026-11-15 in Access's
  ADR).
- Jump edges between `auth-app-ww` and `base-app-ww` exist; destination URL at most 2,048
  characters.

## Work

1. Storage per "Storage target": `client_registrations`, `client_registration_statuses` (five
   states), the handoff `jti` receipt table; all NOT NULL, partial unique indexes as specified;
   reversible migrations; models with matching validations (`database_consistency` must stay at 0).
2. Receivers for H1, H3, H5 as top-level GET routes (resourceful, per `generic/routing.mdc`) that
   verify (Auth JWKS, PS256, `typ` per kind, `iss`, `aud`, `exp`, 120 s, `jti` once, `cer`), commit,
   and answer 303 to the next Jump URL with the signed H2, H4 or H6. Fixed 400/503 refusal page when
   verification fails or sign-up is unavailable. `no-store`, `no-referrer`; never log tokens.
3. Lifecycle writers exactly as in "Lifecycle", "Start (H1)", "Credential registration and
   completion (H3)", "Cancellation (H5)", "Expiry and cleanup" (request-time deadline under the row
   lock, five-minute sweep job, `ClientRegistrationPurgeJob` after 7 days), "Interruptions" and the
   "already done" page rule. Completion in one `app_zenith` transaction; Client status `ACTIVE`.
4. Browser binding: `__Host-` cookie secret, digest stored, one pending registration per browser.
5. Telephone passcode as a Governance step after completion (O-4); report its route.
6. Audit through the same-transaction Chronicle outbox.
7. Write `docs/pending-registration-routes-contract.md`: the exact receiver paths for H1, H3, H5 on
   `https://www.umaxica.app`, and where Access must send the browser after H2, H4, H6 (Access paths
   are Access's choice; state only what Governance needs). The owner will copy this file to Access.
8. Update the Mermaid lifecycle and inventory from "accepted, not implemented" to implemented, the
   README and checklists.

Stop and report (continue the rest) when an item needs a contract that differs from the ADR, a new
environment variable or credential, or an irreversible migration.

## Tests (Red first)

Through the public receivers with real verification (test keys, no mocked verifier): start,
supersede by fresh proof, completion, cancel, cancel after completion, expiry at the boundary
(below, at, above 30 minutes), replayed `jti`, wrong `typ` (an H2 presented as H1, the front-channel
ID Token presented as H1), wrong `cer`, other browser, ineligible birthdate, oversized credential
refused, purge at 7 days, concurrent completion (real concurrency), no Client row before completion,
completed Client is `ACTIVE`. Static guard: no HTTP client reachable from these receivers except the
JWKS client.

## Checks and report

bin/rails zeitwerk:check, bin/rubocop, bundle exec erb_lint --lint-all, bin/brakeman --quiet
--no-pager --exit-on-warn --exit-on-error, RAILS_ENV=test bundle exec database_consistency (exit 0),
the changed tests, then bin/rails test (separate pre-existing failures; unset
`POSTGRESQL_TEST_PREPARE_DATABASES` if its stale list blocks boot).

Evidence: `evidence/YYYY-MM-DD-pending-registration-implementation-XXXX.md` (full
`git rev-parse HEAD`): migrations, routes, measured handoff sizes, test results, stopped items,
confirmation that config/credentials files are unchanged.
