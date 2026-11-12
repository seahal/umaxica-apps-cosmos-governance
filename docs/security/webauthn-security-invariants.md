# WebAuthn Security Invariants

These rules describe the retained RP configuration and signed-result boundary. This Rails
application does not expose browser WebAuthn sign-in, registration-start or assertion-verification
routes. Base and Tech OIDC sign-in is unavailable after removal of its provider URLs and callback
routes. Persisted passkey records and their migrations are retained.

## Surface and origin binding

- Resolve RP ID and origin from an explicit app or org surface. Never derive either value from
  `request.host` or `request.base_url`.
- Reject shared RP ID or origin environment keys. Each active surface has its own configuration.
- Do not infer the surface from a controller class name or mutate global `WebAuthn.configure`
  state.
- The RP ID must equal the configured origin host. Origin checks compare scheme, host and effective
  port.
- A browser WebAuthn verifier must receive an explicit relying-party instance if one is
  reintroduced.

`test/unit/security/webauthn_invariants_test.rb` guards these source-level boundaries, and
`test/unit/webauthn/relying_party_config_test.rb` exercises the configuration value.

## Signed-result consumption

- A passkey result must have the expected token type, issuer, audience and purpose.
- Bind the result to the same surface, actor, session and transaction as the pending completion.
- Reject expired or already consumed transactions before writing a credential.
- Route credential writes through `PasskeyRegistrationOperation`; it locks the owning actor and
  records the audit outbox event in the same transaction.
- Keep `webauthn_id` unique per app or org credential store. A credential cannot move between
  owners or surfaces through metadata or browser-supplied identifiers.

## Metadata and authority

Authenticator metadata is limited to the explicit display columns accepted by
`Webauthn::AuthenticatorMetadata.permit`. AAGUID, provider name, transports, backup flags and
attachment data do not grant access, establish an actor, or satisfy step-up by themselves.

See [Passkey inventory and signed results](passkeys.md) for current route behavior and
[RP ID and Origin boundary](webauthn-rp-id-origin-boundary.md) for the configuration contract.
