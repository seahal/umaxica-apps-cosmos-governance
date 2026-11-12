# Base and Tech Surface Boundary

Base app, Base org, Base com, and Tech org are the repository-owned browser and operator surfaces.
Their route, controller, session, and authorization boundaries remain separate.

Auth and Visa URL configuration and local routes have been removed. Base and Tech sign-in, OIDC
callbacks, logout handoffs, and OIDC-driven step-up cannot start. Base's `.well-known/jwks.json`
routes serve local security key sets and do not provide OIDC discovery or sign-in.

| Surface | Current local contract |
| --- | --- |
| Base app | Product, identity, preference, membership, health, and API routes; RP authentication fails closed |
| Base org | Organization and operator management, identity, preference, health, and API routes; RP authentication fails closed |
| Tech org | Operator dashboard, health, revision, and API health routes |
| Base com | Anonymous public and preference routes; no RP session or credential routes |
| Operator tools | Individually host-constrained tools with tool-local Basic Auth |

The retired product route and controller trees have no redirects, aliases, or compatibility routes.
Their retained model and database state is recorded in the surface hard-reset evidence for a later
cleanup step.
