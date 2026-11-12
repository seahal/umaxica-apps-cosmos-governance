# Subdomain Map

Subdomain labels are entry points. They are not Rails Engine boundaries.

## Routes served here

| Surface | Host label | Ownership |
| --- | --- | --- |
| Base app | `base.app` | Base browser RP, identity, preference, and product APIs |
| Base com | `base.com` | Anonymous public preferences and operational endpoints |
| Base org | `base.org` | Base organization and operator management |
| Tech org | `tech.org` | Separate global operator browser RP |
| Operator tools | `mission`, `flipper`, `blazer`, `pghero`, `swagger`, `coverband` | Host-constrained local tools with their own Basic Auth |

Local development uses the Base app/com/org and Tech org `*.localhost` hosts. Operator tools use
their dedicated governance hosts. The read-only `.devcontainer/compose.yaml` mount still contains
retired host aliases; the
[round 2 evidence](../../evidence/2026-11-11-governance-round2-R2A7.md) records that configuration
blocker and the failed write attempt.

## Removed provider configuration

Auth and Visa URL configuration and local routes have been removed. Base and Tech RP sign-in,
callback, RP-initiated sign-out, Back-Channel Logout, and OIDC-driven step-up routes are absent.

## Retired local surfaces

Retired product route/controller trees are no longer served by this repository. Their retained
models and databases are listed in the
[surface hard-reset evidence](../../evidence/2026-11-11-surface-hard-reset-V4N8.md).
