# WebAuthn RP ID and origin boundary

> **Superseded for Governance runtime (2026-11-13):** Access owns browser WebAuthn ceremony
> execution and its RP ID/origin verification. Governance has no local browser assertion, passkey
> registration, signed-result consumption, or RP configuration path. The rules below preserve the
> security rationale for the service that owns ceremony execution; they are not implemented by this
> Governance application.

WebAuthn credentials are scoped to a relying party and a browser origin. The ceremony owner must
bind the RP ID and origin to an explicit surface, require the configured HTTPS origin in production,
and compare scheme, host, and effective port. Request host data and redirect parameters are not
verification evidence. A browser assertion is accepted only after the owner validates the signed
WebAuthn response and its actor, session, and transaction binding.

Governance retains Client and Operator credential records and maps them to their owning app or org
surface through `Webauthn::Surface`. That data ownership mapping is not an RP configuration object.
Governance also retains RP-local step-up state and the Access handoff; neither establishes that a
local WebAuthn assertion was verified.

## Related

- [Passkey lifecycle and audit](passkey-lifecycle-and-audit.md)
- [WebAuthn security invariants](webauthn-security-invariants.md)
- [Redirects versus authentication evidence](redirect-vs-ceremony-result.md)
