# Jump RT Key Rotation

## Scope and ownership

Jump RTs issued by Governance use the repository's shared PS256 signing key set and the issuer
identity of the selected surface. Base app and Base org continue to have distinct `iss` values and
return policies, but publish the same repository public keys. Follow
[`jwt-key-rotation.md`](jwt-key-rotation.md) to rotate Governance's signer.

This runbook does not rotate the external Jump gateway's return-signing key. Rails verifies return
tokens against the gateway JWKS and may reject a compromised gateway key with
`JUMP_RETURN_REVOKED_KIDS`; the gateway owner must rotate its own private key and JWKS.

## Governance issuer key procedure

1. Follow the planned rotation procedure in [`jwt-key-rotation.md`](jwt-key-rotation.md), including
   pre-publishing the replacement public JWK before switching the single repository signer.
2. Coordinate the new Governance `kid` and PS256 public key with the Jump gateway owner. Confirm the
   gateway's exact issuer registration, JWKS fetch, and token verification before cut-over.
3. During cut-over, change `AUTH_JWT_ACTIVE_KID` and the only private entry in
   `AUTH_JWT_PRIVATE_KEYSET` together. Keep the previous Governance public JWK in
   `AUTH_JWT_PUBLIC_KEYSET` through the full verification window.
4. Confirm a Rails-issued Jump RT uses `alg=PS256`, the new `kid`, the expected surface `iss`, and
   the configured Jump audience. Confirm the gateway accepts the new token.
5. Retire the prior public JWK only after the longest first-party token lifetime and all consumer
   cache windows have elapsed.

Governance must not hold the Jump gateway's private signing key. Rails return verification remains
PS256-only and fails closed when its JWKS cannot be fetched or its token fails validation. Verify
the gateway's live signer and published key before production traffic relies on this cut-over; this
repository change does not update or verify that external service.

## Emergency revocation

For a compromised Governance key, use the shared repository procedure and invalidate cached JWKS at
Jump. For a compromised gateway return-signing key:

1. Add the gateway `kid` to `JUMP_RETURN_REVOKED_KIDS` on every Rails receiver and deploy the
   configuration.
2. Have the gateway owner replace its signing key and remove the compromised public key from its
   JWKS.
3. Confirm Rails rejects return tokens carrying the revoked `kid`, including when a cached JWKS
   still contains that key.

Do not log full tokens, private key material, or secret values. No external key provisioning,
gateway registration, deployment, or cache purge is performed by this repository change.
