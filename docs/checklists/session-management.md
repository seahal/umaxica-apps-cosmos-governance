# Session management

Applies to session establishment, pending sign-in and revocation on every supported surface.

- SESSION-1: A successful session-establishment result means committed session authority; pending
  sign-in and recorded authentication evidence do not masquerade as an issued session.
- SESSION-2: Cookies, current-resource state and success audit follow the committed establishment; a
  refusal or failed transaction does not produce success state.
- SESSION-3: Root-login cooldown uses the root-login establishment anchor, not refresh, step-up or
  RP connection times; refusal does not disclose account existence or the remaining interval.
- SESSION-4: Issuance and revocation failures remain failures; database errors are not treated as
  absent sessions or successful revocations.
- SESSION-7: Across all surfaces, application-signed and encrypted messages accept JSON only.
  Authenticated Marshal payloads are refused without a legacy-reader fallback
  ([message serializer configuration](../../config/application.rb)).
- SESSION-8: Base App and Base Org each expose a neutral `GET /sign` / CSRF-protected `POST /sign`
  entry, `GET /sign/interruption`, and `GET /oidc/callback`. OIDC state and token verification use
  the owner-approved `response_type=id_token` profile: state and response `iss` are checked before
  the exact PS256 token is verified with Visa JWKS; the two-minute ID Token JTI is consumed once
  before the corresponding `rp_base_app` or `rp_base_org` session is committed. The callback returns
  303 with no token in the URL, `Cache-Control: no-store`, and `Referrer-Policy: no-referrer`; it
  installs no Access or Refresh Token cookie. Expired sessions renew through Visa with `prompt=none`
  and may extend only the matching expired session and `sid` binding. Signed-in sign-out requires a
  CSRF-protected `POST /sign/out`, revokes that local session before clearing RP credentials, and
  sends the no-hint Visa confirmation through Jump. The completion is bound to the one-time state
  and revoked local session.
- SESSION-9: Each Base RP `POST /oidc/closures` endpoint has no browser-session or CSRF dependency.
  It accepts only a verified Visa PS256 Logout Token for that cell's fixed client, commits its
  replay receipt, `sid` tombstone, and matching local session revocations in that cell's own
  database, then returns 200. Persistence and JWKS dependency failures return 503; conflicting reuse
  of a JTI returns 409.
- SESSION-10: Base App and Base Org are first-party relying parties; these routes do not implement
  Visa authorization or credential ceremonies. Sign-in makes no server-side Access call other than
  reading Visa JWKS; Access must complete the owner-approved front-channel ID Token response and
  Jump deployment trust remains external. Governance Base API calls use a distinct short-lived PS256
  bearer derived from and checked against the caller's active RP session. Tech browser OIDC sign-in
  remains disconnected, while its capability API uses the Governance bearer. OIDC-driven step-up
  callbacks remain absent; expired sessions cannot authorize requests and renew only through the
  `prompt=none` flow.

Sources: [root-login boundary](../../adr/root-login-establishment-boundary.md),
[session issuance rule](../../.agents/harnesses/rules/project/session-issuance.mdc). Implementation
paths and test inventory remain in those sources; this list records no test result.
