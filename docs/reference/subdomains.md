# Subdomain Map

Subdomain labels are entry points. They are not Rails Engine boundaries.

## Routes served here

| Surface        | Host label                                                       | Ownership                                               |
| -------------- | ---------------------------------------------------------------- | ------------------------------------------------------- |
| Base app       | `base.app`                                                       | Base browser RP, identity, preference, and product APIs |
| Base com       | `base.com`                                                       | Anonymous public preferences and operational endpoints  |
| Base org       | `base.org`                                                       | Base organization and operator management               |
| Tech org       | `tech.org`                                                       | Separate global operator browser RP                     |
| Operator tools | `mission`, `flipper`, `blazer`, `pghero`, `swagger`, `coverband` | Host-constrained local tools with their own Basic Auth  |

Local development uses the Base app/com/org and Tech org `*.localhost` hosts. Operator tools use
their dedicated governance hosts. The read-only `.devcontainer/compose.yaml` mount still contains
retired host aliases; the [round 2 evidence](../../evidence/2026-11-11-governance-round2-R2A7.md)
records that configuration blocker and the failed write attempt.

## RP and provider routes

Governance does not serve the Visa provider or credential ceremonies. Base App and Base Org each
serve a neutral `/sign` entry, `/oidc/callback`, RP-local sign-out and `/oidc/closures`;
authorization and logout navigation leave through Jump. Access's Visa Org authorization endpoint
currently answers 503. Tech RP routes remain absent, as does the OIDC-driven step-up callback.

## Retired local surfaces

Retired product route/controller trees are no longer served by this repository. Their retained
models and databases are listed in the
[surface hard-reset evidence](../../evidence/2026-11-11-surface-hard-reset-V4N8.md).
