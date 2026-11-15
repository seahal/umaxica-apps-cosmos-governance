# Runtime Role Boundaries

## Shared process constraints

Development and test use one Rails-standard credentials set and one database login for every role.
Production also uses one credentials set; per-role credentials bundles are not configured. One Puma
serves every retained host. A runtime role is a routing and key-use boundary, not an
operating-system, credential-file, or database-grant boundary.

Every process reads `UMAXICA_RUNTIME_ROLE` once at boot. An unknown or missing role fails startup.
Role ownership is declared in `RuntimeRole.route_owner`; the route guard refuses an unowned
controller instead of assigning it a default owner.

## Retained ownership

- Base app and org controllers use their own RP session boundaries. Base com routes are anonymous
  Preference, health, revision, crawler, and browser-chrome endpoints.
- Tech org serves the operator tools surface and its own health and revision endpoints.
- Base app/org own the public JWKS routes. Base owner APIs retain their declared Base or domain
  authority owners.
- Mission Control Jobs, Flipper, Blazer, PgHero, Swagger, and Coverband are mounted on separate
  governance hosts and use their own middleware authentication.
- An unknown host reaches only the explicit unknown-host handler.

Governance does not host the Visa provider or credential ceremonies. Base App and Base Org each have
an RP entry, callback, local sign-out and Back-Channel Logout receiver, backed by separate RP cells
and their configured Visa issuer. External authorization and logout navigation use Jump. Tech has no
RP protocol routes.

## RP cell roles

An RP cell role serves only the controllers assigned to that cell. It validates a Base browser
access token against its configured issuer keys, follows its session binding to the owning browser
session and current root token, and checks the live actor and authentication epoch. The RP access
cookie is not a fallback when that chain is absent or invalid.

`UMAXICA_RP_BROWSER_ADMISSION` is required for `rp-*` roles and accepts `open` or `closed`. A closed
cell serves only health and revision paths. This setting controls whether the cell serves browser
routes; it does not provide sign-in or create credentials.

An RP cell process uses the Governance repository's shared PS256 private key set for client
assertions and other first-party JWTs. Base app/org cells use that same signer for Jump RTs; issuer
and audience claims retain their purpose boundaries. The local keyset installer removes other
private keys from an RP cell environment; this limits the keys the process uses but does not isolate
data from the shared credentials file.

## Current limits

All roles run in the same development container and read the same credentials and database login.
Per-role secret isolation is not planned. A compromise of a process can therefore expose secrets
outside the role's intended key-use list. Keep the host, route, session, and authorization
boundaries explicit even though they do not replace process-level isolation.
