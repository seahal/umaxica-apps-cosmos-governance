# RP OIDC `state` as a Signed JWS and the Return Target

## Status

**Accepted (2026-10-23); RP Rails slice implemented 2026-10-24 (WU-39).** Owner decisions D-149,
D-150, D-151, D-152, D-153, D-154, D-155, D-160, D-162 of the 2026-10 authentication cycle;
implementation in its work unit WU-43. The current implementation covers the RP-owned signed state,
path-only target, one-pending entry rule, callback interruption, and related Rails tests. Production
key rotation, external Jump/Edge behavior, and deployment evidence remain separate operational work.
Amended 2026-11-13: state uses Governance's repository-wide PS256 key set.

## Decision

1. **`state` is a PS256 JWS** signed with Governance's shared repository key set; it has no
   state-specific signing key. Header `typ` `umaxica-oidc-state+jwt`; `alg` exactly PS256 in the
   header and verifier allow list; `kid` resolves in the repository key set. Claims at least `iss`,
   `aud` (state-specific), `jti`, `iat`, `exp`, `v`, and `target_link_uri`; never `sid`,
   `code_verifier` or session secrets. Verification uses the `jwt` gem's supported options
   (`verify_expiration`, `verify_not_before`, `verify_iat: { leeway: 30 }`; see
   [JWT validation](jwt-validation-and-key-risk-decisions.md)).
2. **Lifetime:** `exp = iat + 30 minutes` on the Rails clock that mints it; no grace; leeway only
   for a future `iat`. The OP curfew is a separate deadline on the database clock; the RP deadline
   ending a few seconds earlier is intended (D-160).
3. **Browser binding:** the RP cookie session holds one pending entry keyed by `jti` with
   `code_verifier` and `nonce`. `POST /sign` replaces any existing entry: one sign-in per browser
   and RP, the last start wins, and an earlier tab is refused at the callback — intended behavior.
   No per-`state` revocation (accepted); PKCE, single-use codes and `nonce` stay. Rails CSRF is
   unchanged and never replaced by `state`.
4. **Return target:** the RP's own `pt` is abolished. A protected page redirects to
   `GET /sign?target_link_uri=<path>`; `/sign` keeps it as a hidden field; `POST /sign` validates it
   again — a relative path on the RP's host, no query, no fragment, no dot segments or double
   encoding, not under `/sign` or `/oidc` — and puts it in `state`. An invalid value is ignored and
   the RP default page is used. After callback validation, code exchange and RP session
   establishment the RP redirects to it once. The path is signed, not encrypted: it is readable to
   the OP, Visa and Jump (accepted; concern recorded in
   `docs/backlog/2026-10-23-rp-target-link-uri-path-exposure.md`). Auth's own signed `pt` lane is a
   different mechanism and is unchanged.
5. **Cancel and abnormal endings:** the OP returns `error=access_denied` with the unchanged `state`
   and `iss`; the OP never reads `state` claims. The RP verifies `state`, consumes the pending
   entry, discards the target and redirects to `GET /sign/interruption`. The same page receives
   every other OP error except `login_required`, an invalid, expired or unknown `state`, a missing
   pending entry, a failed code exchange and a failed ID Token or `nonce` check. The page is one
   generic page (customer-visible copy, ja "ログインできませんでした。再度ログインしてください。",
   en "Sign-in could not be completed. Please sign in again."), shows no reason, never redirects on
   its own, writes nothing and is `no-store`; the reason is a server-side reason code only.
6. **Key rotation:** Governance rotates the shared repository key set. An old public key remains
   verifiable for at least the longest first-party token lifetime (currently 400 days for
   Preference) and the applicable leeway; state tokens alone do not shorten that shared window.

## Supersession

- [Redirect target lanes](redirect-target-lanes-pt-nt-xt.md) and
  [signed return targets](signed-return-targets-only.md): the RP lane's `pt` is replaced by
  `target_link_uri`; Auth's `pt`, `nt` and `xt` lanes are unchanged.

## Base first-party profile amendment (2026-11-14)

For Base App (`base-app-ww`) and Base Org (`base-org-ww`) only, the owner-approved
[`front-channel ID Token profile`](oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md)
does not use Authorization Code or PKCE. `POST /sign` still creates the signed, PS256, browser-bound
state and stores its nonce and creation time in the Rails session; the pending entry contains no
`code_verifier`. After the callback verifies state and response issuer, it verifies the
front-channel ID Token with Visa JWKS and redirects to the same path-only return target. Other
clients keep the code and PKCE contract above.
