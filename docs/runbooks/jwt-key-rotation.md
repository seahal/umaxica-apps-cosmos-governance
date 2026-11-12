# JWT Key Rotation

## Scope

Use this runbook for the JWT key families still configured by this Rails process:

- browser access tokens accepted by Base app/org;
- anonymous Preference tokens for Base app/com/org;
- Base app/org Jump return tokens;
- private-key JWT assertions used by retained Base and Tech owner APIs;
- public JWKS served by Base app/org.

This repository no longer exposes an Auth or Visa provider endpoint or starts provider sign-in,
callback, or logout flows. `AUTH_JWT_*` remains the configured access-token key family used by the
retained Base browser-token contract; the name does not imply a local Auth surface.

## Key families

| Family | Environment names | Current use |
| --- | --- | --- |
| Browser access | `AUTH_JWT_ACTIVE_KID`, `AUTH_JWT_PRIVATE_KEYSET`, `AUTH_JWT_PUBLIC_KEYSET`, `AUTH_JWT_REVOKED_KIDS`, `AUTH_JWT_ISSUER`, `AUTH_JWT_CLIENT_AUDIENCES`, `AUTH_JWT_OPERATOR_AUDIENCES`, `AUTH_JWT_CLIENT_CLIENT_ID`, `AUTH_JWT_OPERATOR_CLIENT_ID` | Base app/org browser access-token verification and issuance code |
| Preference APP | `PREFERENCE_APP_JWT_ACTIVE_KID`, `PREFERENCE_APP_JWT_PRIVATE_KEYSET`, `PREFERENCE_APP_JWT_PUBLIC_KEYSET`, `PREFERENCE_APP_JWT_REVOKED_KIDS` | Base app anonymous Preference tokens |
| Preference COM | `PREFERENCE_COM_JWT_ACTIVE_KID`, `PREFERENCE_COM_JWT_PRIVATE_KEYSET`, `PREFERENCE_COM_JWT_PUBLIC_KEYSET`, `PREFERENCE_COM_JWT_REVOKED_KIDS`, `PREFERENCE_COM_JWT_ISSUER`, `PREFERENCE_COM_JWT_AUDIENCE` | Base com anonymous Preference tokens |
| Preference ORG | `PREFERENCE_ORG_JWT_ACTIVE_KID`, `PREFERENCE_ORG_JWT_PRIVATE_KEYSET`, `PREFERENCE_ORG_JWT_PUBLIC_KEYSET`, `PREFERENCE_ORG_JWT_REVOKED_KIDS` | Base org anonymous Preference tokens |
| Base Jump RT and JWKS | `JWT_BASE_APP_ACTIVE_KID`, `JWT_BASE_APP_PRIVATE_KEY`, `JWT_BASE_APP_PUBLIC_KEYSET`, `JWT_BASE_APP_REVOKED_KIDS`; corresponding `JWT_BASE_ORG_*` names | Base app/org Jump return tokens and public JWKS |
| Client assertions | `OIDC_CLIENT_<NAMESPACE>_ACTIVE_KID`, `OIDC_CLIENT_<NAMESPACE>_PRIVATE_KEY`, `OIDC_CLIENT_<NAMESPACE>_PUBLIC_KEYSET`, `OIDC_CLIENT_<NAMESPACE>_REVOKED_KIDS` | Base app/org and Tech org owner API assertions |

The registered client namespaces are `BASE_RP_APP_WW`, `BASE_RP_ORG_WW`, and `TECH_ORG_WW`.
The registry requires client-key material for `TECH_ORG_WW` in the shared process and requires the
current client key in a cell process. Runtime configuration validates active keys, matching public
JWKs, issuer/audience separation, revoked kids, and globally unique kids at boot.

Private keys are loaded once at boot. Public JWKs are derived once from their private keys; request
handlers do not parse keysets, read key files, call KMS, or make network requests to sign a token.
Public keysets contain public JWK fields only.

## Rotation

1. Generate a P-384 ES384 key and choose a globally unique `kid`.
2. Add the new public JWK as a grace key while keeping the current signer active.
3. Deploy and confirm boot validation passes on every process that loads the key family.
4. Switch `ACTIVE_KID` and the matching private key together, then deploy all signers.
5. Confirm newly issued tokens carry the new `kid` and verifiers accept both active and grace keys.
6. Keep the old public key until the longest token or signed-state lifetime and the applicable
   verifier/cache grace period have elapsed.
7. Remove the old public key and deploy the pruned keyset.

For Jump RT, also follow [Jump RT key rotation](jump-rt-key-rotation.md) and confirm the published
Base JWKS is reachable from the Jump service. Client assertions are short-lived and their rotation
must retain the old public key for any assertion already in flight.

## Emergency revocation

1. Add the compromised `kid` to the family’s `*_REVOKED_KIDS` setting and remove its public key
   from the published keyset.
2. Deploy verifiers first and confirm the revoked key is rejected.
3. Install and activate a new private key, then deploy signers.
4. Confirm new tokens use the replacement `kid` and the public JWKS contains only approved keys.

Record key IDs, affected family names, deployment revisions, and verification time in the release
evidence. Never record key material, tokens, or environment values in evidence.
