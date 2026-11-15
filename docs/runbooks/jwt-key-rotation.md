# Governance JWT Key Rotation

## Scope and trigger

This procedure rotates the single Governance signing key set used by first-party JWTs: Auth access
tokens, Preference tokens, RP client assertions, OIDC client assertions and ID tokens, Jump RTs, and
locally issued ceremony tokens. Token claims and issuer records remain purpose-specific. This
runbook does not rotate Access's OpenID Provider keys or the Jump gateway's return-signing key.

Use this procedure for a planned key rotation or an emergency replacement. The protocol is PS256
only; there is no ES384 overlap or fallback.

## Configuration and prerequisites

The runtime reads this repository key set through `JitSecurityJwtKeySource` from environment or
Rails credentials:

- `AUTH_JWT_PRIVATE_KEYSET`: JSON object mapping `kid` values to strict Base64-encoded PKCS#8 RSA
  private-key DER. The active key must be RSA 3072 bits or larger.
- `AUTH_JWT_PUBLIC_KEYSET`: public JWK Set JSON containing current and grace RSA PS256 signing keys.
- `AUTH_JWT_ACTIVE_KID`: the key used to sign new JWTs.
- `AUTH_JWT_REVOKED_KIDS`: optional comma-separated revoked `kid` values, read from the environment.

Only the active private key belongs in `AUTH_JWT_PRIVATE_KEYSET`; grace keys are public-only. The
active public JWK must match the private key, and all public JWKs must use `kty=RSA`, `alg=PS256`,
`use=sig`, and public members only. Keep issuer, audience, `typ`, purpose, and lifetime settings
unchanged during key rotation. Do not place secret values or key material in this runbook.

The local installer creates disposable RSA 3072 keys in `tmp/local_jwt_keysets.json` for development
and test. Clearing that store invalidates previously issued local tokens. Production key
provisioning and deployment are outside this repository procedure and must be performed by the
authorized secret owner.

## Planned rotation

Let `K1` be the active key and `K2` the replacement. Coordinate the cut-over with every verifier
that consumes Governance's shared JWKS, including Access registrations and the Jump gateway. This
repository does not perform those external registrations or deployments.

1. Generate `K2` as RSA 3072 or larger and choose a new repository-unique `kid`.
2. Publish the public JWK for `K2` as `state=grace` in `AUTH_JWT_PUBLIC_KEYSET`, retaining the `K1`
   public JWK. Keep `K1` as `AUTH_JWT_ACTIVE_KID` and its private key as the only private entry.
3. Deploy the pre-published JWKS and confirm all consumers can fetch it before switching signers.
4. In one deployment, set `AUTH_JWT_ACTIVE_KID` to `K2`, replace the sole private entry with `K2`,
   and mark `K2` active in the public JWK Set. Retain `K1` as a public-only grace key. The registry
   rejects a mismatched active key, so these values must change together.
5. Verify boot validation, the public JWKS, and a locally issued token's `alg=PS256` and `kid`. Run
   the relevant integration checks against each consuming verifier before declaring the rotation
   complete.
6. Retain `K1` in the public JWK Set through the longest first-party token lifetime (currently 400
   days for Preference) plus the applicable verification leeway. Then remove its public JWK. Retain
   its private secret version only as long as the approved rollback window requires.

If a consumer cannot be prepared for this PS256-only cut-over, stop the deployment and record the
consumer and required owner action. Do not temporarily accept ES384.

## Emergency revocation

1. Provision a replacement RSA key and public JWK.
2. In one deployment, set the replacement as active, include only its private key, add the
   compromised `kid` to `AUTH_JWT_REVOKED_KIDS`, and remove the compromised public JWK.
3. Purge or invalidate cached Governance JWKS at every consumer and apply that consumer's revocation
   mechanism. A Rails-side revoked-kid setting cannot force an external verifier to discard an
   already cached public key.
4. Confirm Governance no longer publishes the key and the external consumers reject tokens carrying
   its `kid`.

Never log JWTs, private keys, secret values, or complete authorization data. Record only the
non-secret key identifier, affected verifier, configuration source name, and verification result.

## Verification and recovery

Before production execution, verify the public keys' RSA size and PS256 metadata, active/private
matching, key identifiers, consumer JWKS reachability, and the maximum issued-token lifetime. A
rollback must restore the previous active kid and matching private key together while leaving every
public key needed by tokens already issued. Emergency revocation overrides normal rollback for a
compromised key.
