# Runtime Role Boundaries

## Shared process constraints

Development and test use one Rails-standard credentials set and one database login for every role.
Production also uses one credentials set; per-role credentials bundles are not configured. One Puma
serves every retained host. A runtime role is a routing and key-use boundary, not an operating-system,
credential-file, or database-grant boundary.

Every process reads `UMAXICA_RUNTIME_ROLE` once at boot. An unknown or missing role fails startup.
Role ownership is declared in `RuntimeRole.route_owner`; the route guard refuses an unowned controller
instead of assigning it a default owner.

## Retained ownership

- Base app and org controllers use their own RP session boundaries. Base com routes are anonymous
  Preference, health, revision, crawler, and browser-chrome endpoints.
- Tech org serves the operator tools surface and its own health and revision endpoints.
- Base app/org own the public JWKS routes. Base owner APIs retain their declared Base or domain
  authority owners.
- Mission Control Jobs, Flipper, Blazer, PgHero, Swagger, and Coverband are mounted on separate
  governance hosts and use their own middleware authentication.
- An unknown host reaches only the explicit unknown-host handler.

This repository has no provider authorization, callback, or logout route. Removing those routes also
removed the corresponding Auth/Visa URL configuration; a new OIDC sign-in cannot be started here.

## RP cell roles

An RP cell role serves only the controllers assigned to that cell. It validates a Base browser access
token against its configured issuer keys, follows its session binding to the owning browser session
and current root token, and checks the live actor and authentication epoch. The RP access cookie is
not a fallback when that chain is absent or invalid.

`UMAXICA_RP_BROWSER_ADMISSION` is required for `rp-*` roles and accepts `open` or `closed`. A closed
cell serves only health and revision paths. This setting controls whether the cell serves browser
routes; it does not provide sign-in or create credentials.

An RP cell process may use only its own private client-assertion key. Base app/org cells also use
their own Jump RT key. Tech has no Jump issuer key. The local keyset installer removes other private
keys from an RP cell environment; this limits the keys the process uses but does not isolate data
from the shared credentials file.

## Current limits

All roles run in the same development container and read the same credentials and database login.
Per-role secret isolation is not planned. A compromise of a process can therefore expose secrets
outside the role's intended key-use list. Keep the host, route, session, and authorization boundaries
explicit even though they do not replace process-level isolation.
