# Cloudflare Request Paths and Trust Boundaries

This document records how requests reach the Rails surfaces that remain after the surface hard
reset. Cloudflare Tunnel, Cloudflare Access, and Workers VPC are distinct trust domains.

## Rails host ownership

Rails host authorization admits the configured hosts for the locally served surfaces only:

- Base app, com, and org;
- Tech org;
- Mission, Flipper, Blazer, PgHero, Swagger, and Coverband tool hosts.

Development admits Base and Tech localhost aliases and the six dedicated operator-tool governance
hosts. No operator tool is routed on a `.core.dev.localhost` host. Unknown hosts reach the explicit
unknown-host responder.

The former Auth, Visa, Core, Warp, Palm, Edit, Docs, News, Help, Info, and Guid hosts are not
local Rails routes. Auth and Visa URL configuration and outbound requests were removed, so this
process no longer contacts those authorities.

## Host versus routing target

A Tunnel ingress `service:` address and a Workers VPC Service address are routing targets. They do
not become the request's Rails `Host` merely because they receive the connection. Rails validates
the HTTP `Host` header and, when present, the last `X-Forwarded-Host` value. A proxy that sets
those headers must preserve the host family intended for the route.

Production browser requests use public surface hosts. Development requests may arrive through the
Access-protected tunnel or a private local ingress; host authorization admits only the configured
current surface hosts for those paths.

## Trust boundaries

- Cloudflare Access authenticates the operator before the request reaches development tools or
  protected development surfaces.
- Rails still enforces its own route, session, authorization, CSRF, and CSP boundaries.
- Base and Tech OIDC sign-in, callback and logout entrypoints are absent. Existing local RP session
  validation, verification and withdrawal routes keep their own browser and authorization checks.
- Operator tools retain their own Basic Auth checks even when an upstream proxy also authenticates.

Do not treat a routing target, development alias, or external authority origin as proof that a
request belongs to another local surface. The controller owner and host constraint remain explicit.
