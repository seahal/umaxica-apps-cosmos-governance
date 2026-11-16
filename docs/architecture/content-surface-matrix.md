# Current Surface Matrix

This matrix is the current route ownership inventory. It replaces the former 3-by-4 content-surface
matrix, whose routes and controllers have been retired from this repository.

| Host surface                                         | Routes kept                                                                    | Authentication boundary |
| ---------------------------------------------------- | ------------------------------------------------------------------------------ | ----------------------- |
| Base app                                             | Product root, identity, preference, membership, health, and API routes         | Base RP                 |
| Base org                                             | Organization management, Base RP, identity, preference, health, and API routes | Base RP                 |
| Base com                                             | Public root, anonymous preferences, health, and revision routes                | Anonymous               |
| Tech org                                             | Operator dashboard, Tech RP, health, and revision routes                       | Tech RP                 |
| Mission, Flipper, Blazer, PgHero, Swagger, Coverband | Individual host-constrained operator tools                                     | Tool-local Basic Auth   |

Governance does not serve Auth or Visa credential ceremonies. Base App and Base Org are relying
parties with separate OIDC entries, callbacks, RP-local sign-out, Back-Channel Logout receivers and
RP cells; Visa authorization and Jump navigation remain external dependencies. Access's Visa Org
authorization endpoint currently answers 503. Tech OIDC sign-in, callbacks, RP-initiated sign-out,
Back-Channel Logout, and OIDC-driven step-up are unavailable. Base com is the only retained
corporate/com surface; no other `.com` or `*_CORPORATE` surface is routed.

Former Docs, Help, Info, News, Guid, Auth, Visa, Core, Warp, Palm, and Edit pages are not served
here. Retained publishing and RP models are listed in the hard-reset evidence for the next
model/database cleanup step.
