# WebAuthn and passkey ownership

Access owns OpenID Provider ceremonies, including browser WebAuthn verification. Governance does not
start or verify WebAuthn ceremonies, consume signed ceremony results, or own RP ID and origin
configuration. Base App and Base Org have relying-party entries and callbacks for verified Visa
responses; these do not provide a Governance-owned credential ceremony. Tech RP routes remain
disconnected.

Governance retains Client and Operator credential records, their metadata, owner-scoped management
pages, and the atomic credential/audit writer. `Webauthn::Surface` maps the app and org ownership
domains to their credential classes and actor foreign keys; it does not configure a relying party.
Passkey metadata is display data and cannot establish identity, authorization, freshness, or
step-up. RP-local step-up state and the Access handoff remain separate from browser WebAuthn.

The historic RP ID/origin and signed-result contracts are retained as migration history in
[the boundary note](webauthn-rp-id-origin-boundary.md). They do not describe executable Governance
ceremony code.

## Related

- [Passkey inventory and ownership](passkeys.md)
- [WebAuthn security invariants](webauthn-security-invariants.md)
