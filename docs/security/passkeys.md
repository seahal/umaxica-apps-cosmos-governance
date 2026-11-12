# Passkey Inventory and Signed Results

## Current surfaces

Base app and Base org retain authenticated passkey inventory pages at `GET /identity/passkeys` and
`GET /identity/passkeys/:id`. They list stored credentials and display their metadata. There are no
local passkey sign-in, registration-start, browser-verification or OIDC callback routes. The
provider URL configuration was removed, so Base and Tech OIDC sign-in is unavailable.

Existing passkey records, models and migrations remain intact. This cleanup does not remove stored
credentials or their audit history.

## Signed result boundary

Base completion operations accept signed ceremony results only after checking the token contract,
surface, actor, session, transaction and expiry. Credential writes go through
`PasskeyRegistrationOperation`, which serializes writes for an owner and records the audit outbox
event in the same transaction. This Rails application does not verify browser WebAuthn assertions.

Passkey identifiers and authenticator metadata are display or protocol data. They do not grant
authorization or replace the owning actor, session, step-up policy or signed result checks.

## Surface ownership

- Base app credentials belong to `ClientPasskey` and use the app RP configuration.
- Base org credentials belong to `OperatorPasskey` and use the org RP configuration.
- RP configuration comes from an explicit surface and requires an exact origin match. Request
  host data does not select an RP.
- The user handle is opaque, immutable and separate from the database primary key.

See [WebAuthn architecture](webauthn-architecture.md),
[WebAuthn security invariants](webauthn-security-invariants.md), and the
[RP ID and Origin boundary](webauthn-rp-id-origin-boundary.md).
