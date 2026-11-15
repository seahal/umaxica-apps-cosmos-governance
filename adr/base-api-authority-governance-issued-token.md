# Base API Authority: Governance-Issued Short-Lived Token (2026-11-14)

## Status

Accepted (owner, 2026-11-14). Completes the first-party front-channel ID Token profile in the
2026-11-14 amendment of `adr/oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md`,
which issues no Access Token to `base-app-ww` and `base-org-ww`.

## Context

Base App and Base Org call Governance's own Base APIs over HTTP (`MembershipAuthorityClient`,
`AvatarAuthorityClient`, `OrgAdminAuthorityClient`, `TechCapabilityClient`; targets come from
`base_for_resource_type`, that is `base_service` or `base_staff`). The bearer is the Access Token
that Access issued at the Token Endpoint, verified by `OidcOpAccessTokenVerifier` with Access's
JWKS. The front-channel profile removes that Access Token, so Governance needs its own authority for
these calls. The callers and the receivers are both Governance; Access has no part in it.

## Decision

1. After the front-channel callback, the Governance RP session (bound to the OP `sid` in
   `rp_op_session_bindings`) is the only source of authority for Base API calls.
2. Governance issues, per call or per short reuse window, a PS256 JWT signed with its own key and
   published in its existing `/.well-known/jwks.json`:
   - `iss` and `aud`: the Governance Base origins of the realm (issuer is the calling Base origin,
     audience the target `base_service` or `base_staff` origin); a token for one realm or audience
     is refused by the other.
   - `typ` distinct from every other token Governance signs (handoff `state`, preference tokens), so
     no token type can be replayed as another.
   - `sub` and `act` from the RP session (separate claims, equal for now), the RP session reference,
     `jti`, `iat`, `exp`. Lifetime at most 5 minutes. No personal data.
3. The receiver verifies signature (Governance JWKS, PS256 only), `typ`, `iss`, `aud`, `exp`, and
   that the referenced RP session is still active. Revocation therefore follows the RP session:
   Back-Channel Logout for a `sid` ends the session, and no further token is issued or accepted.
4. Access Tokens and Refresh Tokens from Access are no longer obtained on the sign-in path. They
   stay only where sign-out still uses them, until a sign-out order removes them.
5. Option kept for later: replace the HTTP self-calls with in-process calls (owner may decide
   separately). This token is the boundary until then.

## Rejected

- Keep fetching an Access Token from Access after sign-in: keeps a dependency on Access that the
  front-channel design removes.
- Reuse the ID Token as a bearer: its audience is the RP client, its lifetime is 2 minutes and it is
  single-use by design.

## Consequences

- No server-side call to Access remains on sign-in or on Base API use; only JWKS reads.
- `OidcOpAccessTokenVerifier` is replaced on these receivers by a Governance-token verifier; the RFC
  9068 profile stays for any remaining Access-issued token consumer and is reported where used.
- Key rotation of the Governance signing key covers this token type; no new key or environment
  variable is introduced.

## Delivered implementation (2026-11-14)

Base App, Base Org, and the existing Tech capability client now issue this token from their local RP
session. The fixed client registry selects the key namespace and realm; every receiver checks the
exact token header and claim set, audience and issuer, then reloads the `sid`-bound session from the
writer before resolving actor authority. Avatar, Membership, and Org Admin clients use the token as
their sole bearer credential. The Tech browser's existing Access authentication is unchanged; only
its server-to-server capability check uses this Governance token. Back-Channel Logout revokes the
local session, and an integration test confirms that a previously issued token is then refused.

Owner-approved API calls that still require Access-owned step-up evidence remain explicitly
unavailable; this implementation does not infer or fabricate that evidence.
