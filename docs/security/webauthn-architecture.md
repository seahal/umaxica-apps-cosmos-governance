# WebAuthn Architecture

The retained local behavior covers passkey inventory, surface-specific RP configuration, and
transactional consumption of signed ceremony results. Browser WebAuthn verification and local
passkey sign-in or registration-start routes are not present. Base and Tech OIDC sign-in is
unavailable because its provider URLs and RP callback routes were removed.

## RP configuration

`Webauthn::Surface` maps the app and org ownership domains explicitly.
`Webauthn::RelyingPartyConfigResolver` loads the RP ID and origin for that surface, while
`Webauthn::RelyingPartyConfig` validates that the RP ID equals the configured origin host and
compares exact scheme, host and effective port. The request host does not select the surface.

Passkey ceremony transaction records resolve their RP configuration from the declared app or org
surface. Step-up session consumption uses the same exact-origin check.

## Signed results and stored credentials

Base completion operations validate the signed result contract and bind the result to its surface,
actor, session, transaction and expiry before writing a credential. Registration uses
`PasskeyRegistrationOperation` to serialize writes for the owning Client or Operator and to persist
the audit outbox event atomically.

Base app and org passkey pages are read-only inventory. Stored credential metadata is display data;
it does not establish identity, authorization, freshness or step-up.

## Related

- [Passkey inventory and signed results](passkeys.md)
- [WebAuthn security invariants](webauthn-security-invariants.md)
- [RP ID and Origin boundary](webauthn-rp-id-origin-boundary.md)
