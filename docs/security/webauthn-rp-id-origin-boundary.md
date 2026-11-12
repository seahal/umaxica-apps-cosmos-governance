# WebAuthn RP ID And Origin Boundary

WebAuthn credentials are scoped to the Base browser surface where the ceremony runs. Base app and
Base org use separate RP IDs and exact origins; neither surface accepts credentials for the other.

`Webauthn::Surface` is the closed set of retained browser surfaces. `Webauthn::RelyingPartyConfigResolver`
loads the configured RP ID and origin for each surface and builds an explicit relying party for the
ceremony. In production, the RP ID must match the configured HTTPS origin host. Missing or invalid
configuration fails during application initialization.

Passkey ceremony transaction records bind their surface, RP ID and origin. Base completion
operations validate signed result tokens against their actor, session and transaction before
committing a credential. Browser navigation and redirect parameters are not evidence of successful
verification. This Rails application does not verify browser assertions.

There are no local browser passkey sign-in or registration-start routes and no RP OIDC callback
routes. Base and Tech OIDC sign-in is unavailable. Existing credential and session state remains
owned by its Base surface.

## Related

- [Passkey lifecycle and audit](passkey-lifecycle-and-audit.md)
- [WebAuthn security invariants](webauthn-security-invariants.md)
- [Redirects versus authentication evidence](redirect-vs-ceremony-result.md)
