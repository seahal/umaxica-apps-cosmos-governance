# Step-Up MFA Status

> **Owner supersession (2026-11-13):** Access owns authentication and step-up ceremony execution.
> Governance retains credential records and step-up policy inputs, but its local setup and
> verification bootstrap routes have been removed. When a protected RP action requires an
> unavailable Access ceremony, Governance returns an explicit unavailable response; it does not
> redirect to a local credential-enrollment flow. The historical enrollment and bootstrap behavior
> described below is not a current route contract.

> **Current route status (2026-11-14):** Base App's RP entry and callback are restored, but no
> credential ceremony or OIDC-driven step-up callback is served by Governance. Access owns those
> ceremonies. Credential-availability state and operation-level step-up checks remain local Base
> behavior; this document does not describe a currently routed step-up flow.

This document describes the credential-availability state used by the Base app and Base org
surfaces. Base com is anonymous-only; Tech does not expose passkey inventory.

Step-up is the product's current `AAL2` boundary. The broader AAL terminology is defined in
`docs/security/authentication-assurance-levels.md`.

## Purpose

Step-up policy inputs describe the credential evidence required by sensitive signed-in actions, such
as credential management, session revocation and withdrawal. They do not start or verify a
credential ceremony in Governance.

## Columns

`multi_factor_id` is the actor policy level. It describes the requested MFA strength and must not be
used as the credential-availability cache.

`multi_factor_status_id` is the credential-availability cache:

| value | name           | meaning                                                                       |
| ----- | -------------- | ----------------------------------------------------------------------------- |
| `0`   | `NOTHING`      | Placeholder only. Runtime checks raise because this is an implementation bug. |
| `1`   | `ACTIVE`       | At least one surface-counting step-up method exists.                          |
| `5`   | `UNCONFIGURED` | No surface-counting step-up method exists. New actors default here.           |

## Surface Criteria

The status is recalculated from surface-specific step-up methods:

| surface | `ACTIVE` when any of these exist                              |
| ------- | ------------------------------------------------------------- |
| `app`   | verified user email, active user passkey, or active user TOTP |
| `org`   | active operator passkey                                       |

When multiple app step-up methods are available, prefer passkey, then TOTP, then email OTP.

### Historical local TOTP verification behavior

Governance retains app TOTP credential records. The attempt selection, verification and counter
handling described below belonged to the former local verifier; Access owns current TOTP ceremony
execution. This historical detail is not a current Governance verification contract.

TOTP is supported only on the `app` surface. `com` and `org` do not gain TOTP enrollment, sign-in,
Step-Up, or settings routes through this status policy. The credential lifecycle and attempt-binding
rules are recorded in `adr/app-totp-credential-lifecycle.md`.

An app TOTP failure belongs to one actor-owned credential. With one active credential the server
selects it; with two active credentials the actor selects by `public_id`. The browser never sends a
database-local credential ID, and a failed guess is never applied to every active credential. The
PostgreSQL counter is consecutive and bounded from 0 through 100. The 100th failure changes that
credential to terminal `REVOKED`; a later correct code cannot reactivate it. Only `ACTIVE` and
`INACTIVE` credentials consume one of the two enrollment slots. Revoked rows remain visible in app
settings so the actor can distinguish `REVOKED` from `ACTIVE`, but no reactivation action is
provided.

Telephone numbers, social identities, and passcodes do not count as step-up evidence. This status
document does not specify their use as sign-in inputs.

Email addresses and telephone numbers are contact identifiers. Contact identifiers are PII used for
notification, reachability, or recovery, and ordinary credential-management flows must preserve at
least one usable contact identifier. This contact-identifier minimum is separate from AAL2
availability: deleting a telephone can violate the contact-identifier minimum even though telephone
is not a step-up method.

## Current route behavior

Governance has no local bootstrap, credential-registration, or credential-verification route. `GET`
and `POST /verification` are the RP handoff boundary; credential verification belongs to Access. The
completion and cancellation endpoints return an explicit unavailable response while Access's query
and revocation API is absent. Base APP and ORG Passkey routes and Base APP TOTP routes are read-only
inventory/detail pages; no registration or verification action is routed. A protected action that
requires unavailable Access evidence fails closed and does not redirect to a local enrollment page.

The pre-split page classes, bootstrap exemptions, and registration behavior described by earlier
revisions of this document are retired. They are not the current route contract.

## MFA Reset Recovery

MFA reset is not a step-up method and must not bypass step-up. The former Base app/org MFA reset
routes are retired; this repository no longer exposes that account-recovery workflow.

No Governance reset or bootstrap route remains. If an approved owner-side credential change leaves
no surface-counting credential, `multi_factor_status_id` is recalculated to `UNCONFIGURED`.
Sensitive RP actions then remain unavailable until the owner provides a supported
credential-enrollment path and Access evidence; Governance does not substitute a local enrollment
flow.

## Restricted Mode

A session established through org Emergency Access is not eligible to perform step-up-protected
operations at all, regardless of the credentials the Operator holds. This is an authentication
context decision rather than a freshness one: the ceremony entry is refused, `StepUpResolver` never
reports satisfaction, and the freshness committer refuses to write. There is no separate Emergency
step-up mechanism, and normal step-up behaviour is unchanged. See
`docs/security/org-emergency-access.md`.
