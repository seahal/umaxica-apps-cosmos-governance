# OIDC Route Status

The local router contains no OpenID Provider authorization, discovery, token, revocation, or logout
endpoints. Governance does not serve Auth or Visa credential ceremonies. Base App and Base Org are
independent RPs with neutral entry, callback, local sign-out, and Back-Channel Logout routes;
authorization and logout handoffs use Jump. Base com and Tech have no RP routes. The Visa Org
authorization endpoint is currently unavailable upstream. OIDC-driven step-up callback routes remain
absent.

Base app and org retain `/.well-known/jwks.json` endpoints backed by the local JIT security key set.
Those endpoints do not publish OIDC discovery metadata or enable sign-in. Base com remains an
anonymous public surface. Tech org remains an operator surface. Each operator tool keeps its own
host constraint and Basic Auth boundary.

The retired product route and controller trees are absent and have no redirect, alias, or
compatibility routes. The Base App and Base Org RP route sets have no alternate compatibility paths.
Their remaining models and databases are listed in the surface hard-reset evidence for a later
cleanup step.
