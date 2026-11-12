# Session Reset Policy

## Current behavior

Base and Tech authenticate requests with their RP access credentials, which are checked against
the persisted session boundary. The Rails session is not the authenticated request credential.
There is no `reset_session` call in current application code, and the former sign-in flow that
rotated Rails session IDs is no longer served.

Base and Tech OIDC sign-in is unavailable because its provider URLs and callback routes were
removed. Do not treat old provider handoffs as current routes.

## Persisted revocation

`reset_session` is not a credential-revocation mechanism. Credential changes and session stops go
through their owning transition operations, which update persisted state and write the existing
audit records. `AuthenticationLogoutCurrentSession` is the shared writer for stopping a current
RP token; it is used by the local session-revocation boundary.

The current surface ownership is described in the
[surface boundary](../architecture/base-auth-seven-rp-boundary.md).
