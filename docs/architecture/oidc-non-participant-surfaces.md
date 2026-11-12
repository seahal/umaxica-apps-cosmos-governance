# OIDC Route Status

The local router contains no authorization, callback, discovery, or logout endpoints for an OpenID
Provider flow. Auth and Visa URL configuration and local routes have been removed. Base and Tech
also have no RP sign-in, OIDC callback, RP-initiated sign-out, Back-Channel Logout receiver, or
OIDC-driven step-up callback routes because those flows require the removed provider endpoints.

Base app and org retain `/.well-known/jwks.json` endpoints backed by the local JIT security key set.
Those endpoints do not publish OIDC discovery metadata or enable sign-in. Base com remains an
anonymous public surface. Tech org remains an operator surface. Each operator tool keeps its own
host constraint and Basic Auth boundary.

The retired product route and controller trees are absent and have no redirect, alias, or
compatibility routes. The removed Base and Tech RP routes have no compatibility paths either.
Their remaining models and databases are listed in the surface hard-reset evidence for a later
cleanup step.
