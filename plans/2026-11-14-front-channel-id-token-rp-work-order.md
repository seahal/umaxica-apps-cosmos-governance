Task (umaxica-apps-cosmos-governance only): switch the Base App and Base Org relying parties to
receive the ID Token through the front channel, so that sign-up and sign-in make no server-side call
to Access except reading Visa's JWKS. No commit. Never print secrets, key material, tokens or
environment values. Never edit config/credentials/*.yml.enc. No push, no deploy, no Cloudflare
change, no change outside this repository.

This container sees only this repository. Facts from Access and Jump are written below; do not look
for sibling checkouts.

Build on `plans/2026-11-14-base-org-sign-entry-and-shared-rp-concerns-work-order.md` (shared,
realm-neutral RP concerns). If that order is not finished, finish it first; this order changes the
same concerns.

## Decision (owner, 2026-11-14; do not reopen)

- During sign-up and sign-in, no application makes a server-side call to another except reading the
  peer's published JWKS. Owner quote: "jwks のパラメタ確認をする以外では、sign up/in で api と
  かを参照するのは禁止".
- The 2026-11-14 amendment of `adr/oidc-authorization-code-only-implicit-and-hybrid-non-adoption.md`
  (already in this repository; read it first) defines the profile: `base-app-ww` and `base-org-ww`
  use `response_type=id_token`; the OP returns `id_token`, `state` and `iss` as GET query parameters
  to `/oidc/callback` through Jump; no Access Token, no Refresh Token; ID Token lifetime at most 2
  minutes; single-use `jti`; claims `iss`, `sub`, `aud`, `exp`, `iat`, `auth_time`, `nonce`, `jti`,
  `sid`, `acr`, `amr` only (`sid` added by the owner the same day; re-read the amendment); `nonce`
  and the signed browser-bound `state` replace PKCE; the RP removes the token from the URL with 303
  at once; `Cache-Control: no-store`, `Referrer-Policy: no-referrer`; never logged. The RP session
  is renewed by passing through the OP again with `prompt=none`.
- Every redirect to a different FQDN goes through Jump.
- `sid` keeps the existing Back-Channel Logout design: the callback binds the RP session to it in
  `rp_op_session_bindings` through `RpCallbackCommitter`, unchanged. `act`, `typ` and `nbf` are not
  in the profile; the verifier for this profile does not require them. Reconcile
  `adr/oidc-claims-decision.md` with a scoped note for this profile.
- Base API authority (owner, 2026-11-14): read `adr/base-api-authority-governance-issued-token.md`.
  The APIs called with the Access Token today (`MembershipAuthorityClient`, `AvatarAuthorityClient`,
  `OrgAdminAuthorityClient`, `TechCapabilityClient`, all targeting `base_service`/`base_staff`) are
  Governance's own. Replace the Access Token with a Governance-signed PS256 token (own key, own
  JWKS, distinct `typ`, realm-bound `iss`/`aud`, lifetime at most 5 minutes) derived from the
  `sid`-bound RP session; receivers also check the RP session is active.
- Scope is sign-up and sign-in. Sign-out (`OidcOpRevocationClient`, back-channel logout endpoint) is
  out of scope; do not change it.

## Observed on 2026-11-14

- `OidcSsoInitiator` sends `response_type=code` with PKCE S256; `OidcCallback` exchanges the code
  with `OidcOpTokenClient` (server-side call to Visa's Token Endpoint) and verifies the ID Token
  with `OidcOpJwksClient`.
- Access is changing in parallel under its own order: it will accept `response_type=id_token` only
  for these two clients, refuse `code` from them, and refuse PKCE parameters from them. Visa
  issuers: `https://visa.umaxica.app` (App), `https://visa.umaxica.org` (Org); JWKS at
  `<issuer>/.well-known/jwks.json`; PS256 only.
- CSP `form-action` lists the Base, Jump, Visa and Auth origins (browsers apply it to the whole
  redirect chain after `POST /sign`).
- Jump limits: destination URL at most 2048 characters. The `state` is about 700 characters, the ID
  Token adds about 1000 to 1200.

## Work

1. Initiator: send `response_type=id_token`, `nonce`, `state`, `scope`, `ri`; no PKCE parameters.
   Remove the verifier storage it no longer needs. Keep the request otherwise as it is.
2. Callback: read `id_token`, `state`, `iss` from the query; refuse a response that also carries
   `code` or `access_token`; verify `state` first, then `iss` equals the realm's Visa issuer, the ID
   Token signature with the Visa JWKS (PS256 only), `aud` equals the realm's client ID, `exp`,
   `iat`, `nonce`, the claim set (`sid` required), and `jti` single use (store consumed `jti` in the
   realm's RP database with a unique constraint and expiry; reversible migration). Then create the
   RP session bound to `sid` and answer 303 to a URL without the token. Errors never echo the token.
3. Remove `OidcOpTokenClient` from the sign-in path. If nothing else uses it, delete it and its
   tests; if sign-out or another path still does, keep it and report the caller.
4. RP session renewal: when the RP session needs renewal, pass through the OP with `prompt=none`
   instead of a Refresh Token; `login_required` sends the user to the normal sign entry. Remove the
   sign-in path's Refresh Token storage if nothing else needs it; report anything kept.
5. Static guard test: no HTTP client class is reachable from the sign-up and sign-in controllers and
   concerns except the JWKS client.
6. Both realms through the shared concerns; realm hooks answer issuer, JWKS URI, client ID.

7. Base API authority per the ADR: issuer in the RP layer, verifier on the receivers replacing
   `OidcOpAccessTokenVerifier` there; `BrowserRpAuthentication` reads the RP session, not an Access
   Token cookie. Stop the Access Token and Refresh Token cookies on sign-in. Keep Refresh Token and
   `OidcOpTokenClient` only while sign-out uses them, and report the caller.

Stop and report (continue the rest) if a Base API consumer needs a claim the RP session does not
hold, or if the Governance signing key cannot serve this `typ` without a new key or variable.

## Tests (Red first)

For both realms: valid ID Token accepted and session created, token removed by 303; `state` missing,
tampered, or from the other realm; `iss` from the other realm; wrong `aud`; bad signature; non-PS256
`alg`; Base API token: valid accepted, other realm or audience refused, other `typ` (handoff
`state`, preference token) refused, expired and lifetime boundary (below, at, above 5 minutes), RP
session revoked by Back-Channel Logout then token refused; `sid` missing refused; a Logout Token
with the same `sid` revokes the session created by the callback; expired, and lifetime boundary
(below, at, above 2 minutes); wrong or missing `nonce`; extra or personal-data claims refused;
replayed `jti` refused (real concurrency for the race); response with `code` or `access_token`
refused; error responses (`login_required` and others) handled without a token; headers `no-store`
and `no-referrer`; nothing logged that contains the token; initiator sends no PKCE. No mocked
verifier for the behaviour under test.

## Checks and report

bin/rails zeitwerk:check, bin/rubocop, bundle exec erb_lint --lint-all, bin/brakeman --quiet
--no-pager --exit-on-warn --exit-on-error, bundle exec database_consistency, bun run check, the
changed tests, then bin/rails test (separate pre-existing failures; unset
`POSTGRESQL_TEST_PREPARE_DATABASES` if its stale list blocks boot). Update README, docs/mermaid RP
session diagrams and inventories, and checklists affected.

Evidence: `evidence/YYYY-MM-DD-front-channel-id-token-rp-XXXX.md` (full `git rev-parse HEAD`): what
was removed or kept and why, migrations, test results, the expected browser behaviour once Access
completes its side, owner items, confirmation that config/credentials files are unchanged.
