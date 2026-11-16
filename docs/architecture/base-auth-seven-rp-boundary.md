# Base and Tech Surface Boundary

Base app, Base org, Base com, and Tech org are the repository-owned browser and operator surfaces.
Their route, controller, session, and authorization boundaries remain separate.

Governance does not serve Auth or Visa credential ceremonies. Base App and Base Org are independent
OIDC relying parties with neutral entries, callbacks, local sign-out and Back-Channel Logout
receivers; each uses its own client, Visa issuer and local RP cell. Visa authorization and Jump
remain external dependencies. Tech sign-in and callback routes remain disconnected. OIDC-driven
step-up callbacks remain absent. Base's `.well-known/jwks.json` routes serve local security key sets
and do not provide OIDC discovery or sign-in.

Base App and Base Org use the owner-approved front-channel ID Token profile: the callback checks
browser-bound state and response issuer before fetching Visa JWKS, then commits a single-use,
`sid`-bound RP session. Renewal uses `prompt=none`. Their own Base API calls carry the
Governance-issued token derived from the active RP session; the API receiver reloads that session
before resolving authority. Tech browser authentication remains on its existing Access path, while
the Tech capability API client uses the same Governance token contract.

Base App and Base Org use the owner-approved front-channel ID Token profile: the callback checks
browser-bound state and response issuer before fetching Visa JWKS, then commits a single-use,
`sid`-bound RP session. Renewal uses `prompt=none`. Their own Base API calls carry the
Governance-issued token derived from the active RP session; the API receiver reloads that session
before resolving authority. Tech browser authentication remains on its existing Access path, while
the Tech capability API client uses the same Governance token contract.

| Surface        | Current local contract                                                                                                                                           |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base app       | Product, identity, preference, membership, health, and API routes; Base App RP protocol routes use Visa and Jump                                                 |
| Base org       | Organization and operator management, identity, preference, health, and API routes; Base Org RP protocol routes use its Visa staff issuer and `rp_base_org` cell |
| Tech org       | Operator dashboard, health, revision, and API health routes                                                                                                      |
| Base com       | Anonymous public and preference routes; no RP session or credential routes                                                                                       |
| Operator tools | Individually host-constrained tools with tool-local Basic Auth                                                                                                   |

The retired product route and controller trees have no redirects, aliases, or compatibility routes.
Their retained model and database state is recorded in the surface hard-reset evidence for a later
cleanup step.
