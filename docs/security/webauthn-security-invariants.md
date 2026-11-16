# WebAuthn security invariants

> **Runtime ownership (2026-11-13):** Access owns WebAuthn ceremony execution and RP ID/origin
> validation. Governance does not expose browser verification or signed-result consumption. The
> former local configuration and verifier source guards were removed with that runtime.

## Governance credential data

- App and org credential records remain in their owning Client and Operator stores.
- `webauthn_id` remains unique within the owning credential store. Metadata and browser-supplied
  identifiers do not transfer a credential between owners or surfaces.
- Route credential writes through `PasskeyRegistrationOperation`; it locks the owning actor and
  records the audit outbox event in the same transaction.
- Authenticator metadata is limited to the display columns accepted by
  `Webauthn::AuthenticatorMetadata.permit`. AAGUID, provider name, transports, backup flags and
  attachment data do not grant access, establish an actor, or satisfy step-up by themselves.
- `Webauthn::Surface` maps app/org ownership to record classes and actor foreign keys. It is not RP
  configuration and does not choose a ceremony origin.

See [Passkey inventory and ownership](passkeys.md) for the current Governance boundary and the
[RP ID and origin boundary](webauthn-rp-id-origin-boundary.md) for its superseded-runtime security
rationale.
