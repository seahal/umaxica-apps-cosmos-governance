# Session Reset Policy

## Current behavior

Base and Tech authenticate requests with their RP access credentials, which are checked against the
persisted session boundary. The Rails session is not the authenticated request credential. The Base
App and Base Org OIDC callbacks reset the Rails session only after the verified callback has
committed the RP-local session, then install that realm's RP cookies. Sign-out first commits local
RP-session revocation, clears RP cookies, and resets the Rails session before external navigation. A
failed post-commit handoff does not restore the revoked session or its credentials.

Base App and Base Org have independent RP entry, callback, local sign-out, and Back-Channel Logout
routes. Access's Visa Org authorization endpoint currently answers 503, so Org authorization depends
on that external service being restored. Tech remains disconnected. Governance does not host
provider or credential ceremonies.

## Persisted revocation

`reset_session` is not a credential-revocation mechanism. Credential changes and session stops go
through their owning transition operations, which update persisted state and write the existing
audit records. `AuthenticationLogoutCurrentSession` is the shared writer for stopping a current RP
token; it is used by the local session-revocation boundary.

The current surface ownership is described in the
[surface boundary](../architecture/base-auth-seven-rp-boundary.md).
