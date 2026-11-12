# Local UI and Host Inventory

This inventory covers the retained Rails surfaces: Base app, Base com, Base org, Tech org and
operator tools. Retired products no longer have local route or controller surfaces. Their route,
namespace and mounted-engine detail is recorded in the
[surface reset evidence](../../evidence/2026-11-11-surface-hard-reset-V4N8.md).

## Retained surfaces

| Surface | Host constraint | Routes in the current route set | Controller and view roots | Notes |
| --- | --- | ---: | --- | --- |
| Base app | Base app host | 178 | `Base::App`; `app/views/base/app`, `app/views/base/shared`, `app/views/layouts/base/app` | Base app pages and APIs remain. OIDC entry, callback, sign-out and logout receiver routes are unavailable. |
| Base com | Base com host | 61 | `Base::Com`; `app/views/base/com`, `app/views/layouts/base/com` | Kept intentionally because this Base `.com` surface has active routes. |
| Base org | Base org host | 189 | `Base::Org`; `app/views/base/org`, `app/views/base/shared`, `app/views/layouts/base/org` | Base operator pages and APIs remain. OIDC entry, callback, sign-out and logout receiver routes are unavailable. |
| Tech org | Tech org host | 10 | `Tech::Org`; `app/views/tech/org`, `app/views/layouts/tech/org` | Tech operator surface remains. OIDC entry, callback, sign-out and logout receiver routes are unavailable. |
| Mission Control Jobs | Operator tool host | 25 | Mounted engine | One mount route and 24 engine routes. |
| Flipper | Operator tool host | 1 | Mounted engine | One mount route. |
| Blazer | Operator tool host | 32 | Mounted engine | One mount route and 31 engine routes. |
| PgHero | Operator tool host | 26 | Mounted engine | One mount route and 25 engine routes. |
| Swagger | Operator tool host | 2 | Mounted engine | Two mount routes; this runtime does not expand engine routes for Swagger. |
| Coverband | No active host constraint | 0 | Conditional mounted engine | The configured engine adds no route in this runtime. |

The retained product and tool rows total 524 routes. The unknown-host fallback adds one. The
complete `bin/rails routes` output also includes framework and unscoped routes; the evidence file
records the route counts and complete listing grouped by host constraint.

## View ownership

Base and Tech templates live under their corresponding `app/views` namespaces. Shared Base page
fragments live under `app/views/base/shared`; surface layouts live under `app/views/layouts/base` and
`app/views/layouts/tech`. Email, PWA and shared UI templates support retained surfaces. Operator
engines provide their own views.

## Host policy

Base com is the only retained `.com` / corporate host family. `PUBLIC_BASE_CORPORATE_URL` and
`PRIVATE_BASE_CORPORATE_URL` remain because Base com has active routes. Corporate URL handling for
other families and the retired product host lists were removed from application configuration.
Base and Tech OIDC sign-in and sign-out are unavailable by owner decision.
