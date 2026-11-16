# Front-Channel ID Token RP Implementation Notes

## Context

- Original work order: `plans/2026-11-14-front-channel-id-token-rp-work-order.md`
- Related decisions: `adr/oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md`,
  `adr/base-api-authority-governance-issued-token.md`, and `adr/oidc-claims-decision.md`
- Implementation date: 2026-11-14

## Decisions Made During Implementation

- A Base RP session cookie presented to a Rails process that is not configured for that RP cell
  fails with 503. An integration test showed that the unconfigured process otherwise answered a
  signed-in Preference update as a guest write, leaving the actor-local Preference unchanged. The
  guard checks only cookie presence; it never reads or logs the cookie value. A request through the
  configured RP cell is separately tested to update the actor-local Preference.
- Governance-owned account and enforcement reads use their Governance APIs. Access-owned session
  lookup, revocation, and step-up requirements stay explicit refusals when their owner authority is
  unavailable; a Governance bearer cannot claim Access Standby authority.
- The old `rp_callback_states` tables are removed because the front-channel callback no longer uses
  Code/PKCE state or stores a PKCE verifier. The down migration recreates the empty table shape but
  cannot restore rows. Pending Code-flow callbacks are intentionally invalidated and must restart
  sign-in through the accepted front-channel profile. Only dedicated test databases were migrated
  during this work.
- Sign-out remains outside the work order. `OidcOpRevocationClient` remains called only by
  `OidcRpLogoutLauncher` when a bound Refresh Token cookie is present; the new callback does not
  install Access or Refresh Token cookies.

## Deviations From the Work Order

- Added an explicit refusal for a Base RP session cookie that reaches an unconfigured process. This
  closes the observed guest-write fallback and is documented in
  `docs/architecture/controller-lifecycle.md`.

## Review Notes

- Both Base RP callback-state migrations were rolled back and reapplied in `RAILS_ENV=test`; the
  migrations completed in both directions.
- The front-channel, replay, owner-authority and affected boundary tests passed. Full-suite results
  and remaining repository checks are recorded in
  `evidence/2026-11-14-front-channel-id-token-rp-FCHB.md`.
- Access-side profile support and Jump deployment trust remain external readiness conditions. No
  sibling repository, credentials file, deployment configuration, or production database was
  changed.
