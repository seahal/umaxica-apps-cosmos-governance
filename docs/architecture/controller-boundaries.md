# Controller Boundaries

The current controller inheritance contract is intentionally narrow:

- `BareController` inherits directly from `ActionController::Base` and owns endpoints whose concrete
  controller/action metadata classifies them as bare.
- Surface-local `ApplicationController` inherits from `ActionController::Base` and owns the
  authentication-aware request lifecycle.

Authentication classification must be declared and audited explicitly by concrete controller/action
metadata. Missing declarations resolve to `:deny_all`.

Base app, Base org, Base com, and Tech org own the only application controller trees. Base com
continues as an anonymous public and Preference surface. Retired product controller trees are
removed.

## Current Boundaries

### BareController

`BareController` is the named base for endpoints classified as bare. It is defined per surface, but
does not inherit the surface-local `ApplicationController`, so it avoids authentication, preference,
Actor, verification, authorization, and other application request lifecycle callbacks.

Common examples:

- health endpoints;
- robots endpoints;
- sitemap endpoints;
- public infrastructure endpoints with no actor semantics.

### ApplicationController

Use the surface-local `ApplicationController` for every endpoint that uses authentication-aware
request machinery.

It owns rate limiting, session/authentication resolution, preference resolution, Actor setup,
verification, authorization, observability, and Actor cleanup in the surface's established order.
Concrete controllers or actions declare one of the supported authentication modes:

| Mode        | Authenticated actor | Anonymous actor | Meaning                                                                       |
| ----------- | ------------------- | --------------- | ----------------------------------------------------------------------------- |
| `:deny_all` | closed              | closed          | Default fail-closed mode for undeclared, disabled, or unclassified endpoints. |
| `:guest`    | closed              | open            | Anonymous-only entry flows.                                                   |
| `:private`  | open                | closed          | Normal authenticated endpoints.                                               |
| `:open`     | open                | open            | Anonymous and authenticated actors are both allowed.                          |

`AUTHENTICATION_MODE` declarations must be local to the concrete controller or action. A parent
constant does not count. Undeclared endpoints are `:deny_all`.

`:open` does not permit authentication failure fallback. Open endpoints must distinguish absent
credentials from invalid, expired, revoked, or malformed credentials. Absent credentials may proceed
as anonymous; invalid credentials must use the normal authentication failure path.

Authentication mode is not the source of truth for Step-Up/AAL. Authorization policy owns the
required assurance boundary, method set, and step-up scope for a concrete actor/action/resource. The
step-up gate owns challenge issuance, redirect, return target validation, continuation, and
ticket/session mutation. Controller/action metadata may exist for route inventory and CI assertions,
but runtime must not use it as a second source of truth for step-up requirements.

Rails owns application-semantic rate limiting, not network-layer firewalling or generic HTTP abuse
controls. Public HTTP flood mitigation, path-based coarse limits, bot filtering, and viewer-IP
allow/deny belong to CloudFront + AWS WAF. ALB and ECS networking own origin gating. See
`adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md`.

## Etc: Temporary Exceptions

Some security-sensitive controllers are not yet migrated to the two-base target with explicit
authentication metadata. These are temporary exceptions, not another boundary category.

An exception is allowed only when a controller needs additional guard state that should first be
captured by concrete controller/action authentication metadata or a narrow local abstraction.

Current exception families:

- Base preference endpoints that are open but intentionally use selected preference-cookie
  pipeline behavior. DBSC registration and verification endpoints were removed by the surface
  hard reset; retained DBSC model state is not an HTTP boundary.

Preferred retirement paths:

- split mixed Open/Private controllers by action boundary;
- move authentication-aware public entry points to surface-local `ApplicationController` with
  explicit `:open` declarations;
- use explicit controller/action authentication metadata for private, optional, and bare
  behavior;
- keep surface behavior local to `app`, `com`, and `org` unless an existing shared concern already
  provides a safe abstraction.

When an exception is migrated, keep its active security checks intact: CSRF behavior, DPoP,
session-limit gate, historical status-103 rejection, and step-up verification must not be removed as
an inheritance side effect.
