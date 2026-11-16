# Public Entrypoints

## Scope

This inventory covers public routes owned by this Rails process: Base app, com and org; Tech org;
and the host-constrained operator tools. The category IDs are enforced by
`test/unit/security/public_entrypoint_inventory_test.rb`.

Framework-owned PWA routes are listed because they are public even though their controller is not
application-owned. Operator tool engines are mounted on separate hosts and protected by their own
fail-closed authentication middleware; their engine routes are outside this inventory.

## Authentication Modes

| Mode        | Login required?         | Meaning                                                                                          |
| ----------- | ----------------------- | ------------------------------------------------------------------------------------------------ |
| `:bare`     | No                      | No application authentication lifecycle. Used for probes, protocol metadata and telemetry sinks. |
| `:open`     | No                      | Anonymous and authenticated actors may enter. Invalid credentials still fail authentication.     |
| `:guest`    | No for anonymous actors | Guest-only entry. Signed-in actors are refused.                                                  |
| `:private`  | Yes                     | Normal signed-in actor endpoint.                                                                 |
| `:deny_all` | Not reachable           | Fail-closed endpoint.                                                                            |

## Documented Public Categories

| ID                       | Entrypoints                                                                                                                    | Security boundary                                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| `PUBLIC_ROOTS`           | Base app/com/org roots and the Tech root                                                                                       | Base com is anonymous. Base app/org and Tech use their own relying-party boundary.                                |
| `PUBLIC_DASHBOARD`       | Base app/org `GET /dashboard`                                                                                                  | Signed-in requests render only the authorized actor's dashboard.                                                  |
| `PUBLIC_HEALTH`          | Base and Tech `/health*`; Base app/com/org and Tech `/api/v0/health.json`                                                      | Bodies contain health status only; public edge access remains blocked per `docs/operations/health-check.md`.      |
| `PUBLIC_REVISION`        | Base and Tech `/revision` and `/api/v0/revision.json`                                                                          | Returns only the deployment revision.                                                                             |
| `PUBLIC_CSP_REPORTS`     | Base and Tech `POST /csp-violation-report`                                                                                     | Browser telemetry intake only; it does not mutate actor, session or account state.                                |
| `PUBLIC_WELL_KNOWN`      | Base app/org `GET /.well-known/jwks.json`                                                                                      | Publishes the RP's own public signing keys.                                                                       |
| `PUBLIC_ROBOTS_SITEMAPS` | Base app/com/org `GET /robots.txt` and `GET /sitemap.xml`                                                                      | Crawler metadata only.                                                                                            |
| `PUBLIC_PWA_OFFLINE`     | Base app/com/org `GET /service-worker` and `GET /offline` (`Rails::PwaController`)                                             | Static fallback assets; no session, actor, tenant or database access.                                             |
| `PUBLIC_PREFERENCE`      | Base `/preference*` and `/api/v0/preferences/*`                                                                                | Login-independent preference endpoints remain host-local to their Base surface.                                   |
| `PUBLIC_WITHDRAWAL`      | Base app `/identity/withdrawal*` and `/identity/privacy/erasure*`                                                              | Authentication, step-up, CSRF and lifecycle guards remain in the Base controllers.                                |
| `PUBLIC_RP_PROTOCOL`     | Base app and org `/sign*`, `/oidc/callback`, `/oidc/closures`                                                                  | Browser routes enforce CSRF; each realm uses its fixed Visa issuer, FQDN and rate limits for Back-Channel Logout. |
| `PUBLIC_BASE_OWNER_API`  | Base `/api/v0/{avatar,membership,iam,support}/*`, `/api/v0/identity/{standing,selection}` and `/api/v0/tech-capability-checks` | Server-to-server owner APIs reapply Base policy and require the established URL-bound caller and actor proofs.    |

## Default Rule

Routes outside these public categories must resolve to `:private` or `:deny_all`, declared by the
concrete controller/action. Base App and Org keep their independent RP boundaries; Tech retains its
own operator relying-party boundary. This inventory grants no cross-surface credentials or state.

Base continues to own canonical avatar and social-graph data through its owner APIs. The user-facing
social screens belong to their owning application. Base app/org keep their local verification and
credential-management routes and separate RP cells. Each realm's RP routes use its fixed Visa
origin; `/oidc/closures` is a server-to-server signed-token endpoint, not an authenticated browser
session endpoint. Governance has no local Visa authorization or credential-ceremony route. Tech has
no local RP protocol routes.
