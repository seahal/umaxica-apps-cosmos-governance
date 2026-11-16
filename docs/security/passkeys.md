# Passkey inventory and ownership

## Current surfaces

Base app and Base org retain authenticated passkey inventory pages at `GET /identity/passkeys` and
`GET /identity/passkeys/:id`. They list stored credentials and display their metadata. Governance
has no local passkey sign-in, registration, browser-verification, or signed-result consumer. Base
App's RP callback accepts verified Visa responses; it does not run a credential ceremony. Base Org
and Tech RP routes remain disconnected.

Existing passkey records, models and migrations remain intact. This cleanup does not remove stored
credentials or their audit history.

## Credential data boundary

Access owns verification and signed ceremony results. Governance retains
`PasskeyRegistrationOperation` as an owner-side atomic credential and audit-outbox writer, but it
has no current ceremony caller. It does not validate browser assertions or authorize a ceremony
result.

Passkey identifiers and authenticator metadata are display or protocol data. They do not grant
authorization or replace the owning actor, session, step-up policy or signed result checks.

## Surface ownership

- App credentials belong to `ClientPasskey`; org credentials belong to `OperatorPasskey`.
- `Webauthn::Surface` selects the owning record class and actor foreign key. Governance does not use
  it to configure or select an RP.
- The user handle is opaque, immutable and separate from the database primary key.

See [WebAuthn and passkey ownership](webauthn-architecture.md),
[WebAuthn security invariants](webauthn-security-invariants.md), and the
[historical RP ID and origin boundary](webauthn-rp-id-origin-boundary.md).
