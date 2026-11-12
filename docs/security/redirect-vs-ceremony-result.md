# Redirects Versus Authentication Evidence

Redirects move browsers. They do not prove that authentication, step-up verification, account
linking, or credential registration succeeded.

## Redirect data

Redirect parameters such as `return_to`, `pt`, `nt`, `xt`, OAuth `state`, and OIDC `state` may carry
validated navigation intent or bind a protocol request. They must not carry credentials, account
state, token claims, or verification results. Each value is validated by its owning resolver before
it affects navigation.

Same-surface destinations may use a validated local path. External destinations go through the
shared redirect boundary and its configured gateway policy. Cross-surface navigation does not grant
the destination access to the initiating surface's credentials, permissions, session, or state.

## Authentication and ceremony results

Authentication and credential changes are committed from verified, purpose-bound server state.
The browser must not turn a redirect target, query string, or fragment into proof. Form submissions
that change local state retain the owning surface's CSRF checks, actor authorization, transaction
binding, expiry checks, and replay controls.

Base app and org retain local verification and credential-management routes. This process has no
provider authorization, callback, or logout routes, so it cannot start a new OIDC sign-in flow.

## Related

- [Redirect target rules](redirect_targets.md)
- [Public entrypoints](public-entrypoints.md)
- [Controller lifecycle](../architecture/controller-lifecycle.md)
