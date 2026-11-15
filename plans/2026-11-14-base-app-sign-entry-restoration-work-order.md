Task (umaxica-apps-cosmos-governance only): restore the Base App relying-party sign entry so a
visitor can start sign-up / sign-in from the Base App header, be sent to the OpenID Provider, and
return through the registered callback. Base Org and Tech Org follow in later orders. No commit.
Never print secrets, key material or environment values. Never edit config/credentials/*.yml.enc. No
push, no deploy, no Cloudflare change, no change outside this repository.

This container sees only this repository. Everything needed from other repositories is written below
under "Contract facts"; do not look for sibling checkouts and do not fetch from the network. The
earlier implementation is in this repository's own history: read it with
`git show eedf4f51e~1:<path>` (`eedf4f51e` is the 2026-11-13 checkpoint that removed it).

## Decision

Owner, 2026-11-14: reconnect Base App as a relying party now. This brings forward the Base App part
of stage 3 in `plans/2026-11-12-handoff.md` ("Base/Tech OIDC sign-in is disconnected on purpose")
and ends that disconnection for Base App only.

Precedence: where this order restores a file that
`plans/2026-11-13-remove-unreachable-ceremony-code-work-order.md` or
`plans/2026-11-11-governance-round2-work-order.md` removed or lists for removal, this order wins for
the files it names. Those orders stay in force for everything else. After this order the restored
code has application callers (routes and the header link), so it is no longer "unreachable".

Observed 2026-11-14 in a browser: `https://www.umaxica.app/` serves the Base App landing page; its
header shows the brand only and the page offers no action. `/sign`, `/sign/out`, `/oidc/callback`
and `/oidc/closures` are unrouted.

## Boundary: what comes back and what does not

Restore the **relying-party** side only: start an authorization request, receive the authorization
response, exchange the code, verify the ID token, commit the RP session in the `rp_base_app` cell,
sign out, and receive back-channel logout.

Do not restore any **ceremony**: sign-in or sign-up forms, passkey, TOTP, one-time-code, social
sign-in, recovery, `sign/in/limitations`, `sign/up/*`, ceremony binding confirmations, or anything
under an `auth`, `visa` or `sign` family namespace. Access runs every ceremony
(`adr/cosmos-base-surface-decomposition.md` decisions 5 and 8). Base offers one neutral entry;
whether the visit becomes a sign-up or a sign-in is decided at the OP
(`adr/sign-in-first-and-sign-up-handoff.md`), so the entry sends no `prompt`.

Step-up (`/verification/oidc/callback`, `verification/setups`) is out of scope: leave it as it is
and report its state.

## Contract facts (read on the host on 2026-11-14; treat as given)

OpenID Provider (Access, Visa App), from its live Discovery document:

- `issuer` `https://visa.umaxica.app`; authorization `/oauth/authorize`; token `/oauth/token`; JWKS
  `/.well-known/jwks.json`; end session `/oidc/logout`; revocation `/oauth/revoke`.
- `response_types_supported` is `code` only; `code_challenge_methods_supported` is `S256` only;
  `authorization_response_iss_parameter_supported` is true; no pushed-authorization endpoint is
  advertised, so do not send PAR.
- `id_token_signing_alg_values_supported` and `token_endpoint_auth_signing_alg_values_supported` are
  `PS256` only. Back-channel logout with `sid` is supported.

How Access registers this client (its static client store):

- Client ID `base-app-ww` (worldwide; never region-suffixed), resource type `client`, audience equal
  to the Client ID, `token_endpoint_auth_method` `private_key_jwt`, key namespace `BASE_RP_APP_WW`,
  allowed scopes `openid profile email`.
- Registered on the Base App public host: redirect URIs `/oidc/callback` and
  `/verification/oidc/callback`; post-logout redirect `/sign/out/completion?ri=<region>` for each
  allowed region; back-channel logout `/oidc/closures`. Access derives all of them from the one
  configured Base App origin, so paths here must match exactly.

Navigation rule: the browser leaves Base for the OP's authorization endpoint through the Jump
gateway, never by a direct cross-origin redirect. The proposal to let OIDC redirects bypass Jump was
discarded by the owner on 2026-11-12. Reuse `CommonRedirect#redirect_to_jump_url`, which is still in
the tree.

Known limits outside this repository (do not work around them; record them):

- Access currently routes `/oauth/authorize` to an "unavailable" controller that answers 503 on
  every method. A real sign-in cannot complete until Access reopens it (separate order in Access).
- The deployed Jump gateway was failing closed on 2026-11-13 (JWKS 503). Whether Jump trusts this
  repository's `rt` issuer and allows the Visa authorization endpoint as a destination is a
  deployment fact you cannot check from here.

## What changed elsewhere since the removed code was written

The same RP code is still live in Sphere (Core App). Compared with `eedf4f51e~1` here, Sphere now:

1. signs and verifies PS256 through `JitSecurityJwtJwk::ALGORITHM` instead of an `"ES384"` literal
   (`OidcStateJwt`, `OidcOpIdTokenVerifier`, `OidcOpLogoutTokenVerifier`). Follow this repository's
   `plans/2026-11-13-ps256-follow-up-work-order.md`: PS256 only, no ES384 path;
2. has no `:direct` branch in `redirect_to_oidc_authorization_url` and no per-client exception in
   `oidc_redirect_decision`: every absolute authorization URL goes through Jump, anything else is
   400;
3. takes the ID token clock leeway from the verifier (`OidcOpIdTokenVerifier`), not from
   `AuthenticationJwtConfiguration`;
4. accepts `private_key_jwt` only in the revocation client and raises on any other method.

Apply 1, 2 and 4 here. For 3 use whichever constant this tree still has and say which. Sphere also
dropped `prompt` / `max_age` from `initiate_oidc_session!`; drop them here for the neutral entry
unless step-up code that remains in this tree calls them (report the caller).

## Work

Part A: entry, callback, header (do this first, keep it reviewable on its own).

1. Inventory before editing. For each path below report: present at `eedf4f51e~1`, present now, and
   what it needs that is missing. Follow references until the set closes (constants, concerns,
   models, views, locales, front-end types). Starting list:
   - controllers `app/controllers/base/app/sign/entries_controller.rb`,
     `sign/interruptions_controller.rb`, `oidc/callbacks_controller.rb`;
   - concerns `oidc_rp_sign_entry.rb`, `oidc_rp_sign_interruption.rb`, `oidc_sso_initiator.rb`,
     `oidc_callback.rb`, `browser_rp_safe_request_refresh.rb`, and the parts of
     `Base::App::ApplicationController` that named the OP host and `sign_in_url_with_target`;
   - values and adapters `app/values/oidc_state_jwt.rb`, `app/values/oidc/acme_service_origin.rb`,
     `app/adapters/oidc_op_token_client.rb`, `oidc_op_id_token_verifier.rb`, the OP JWKS client;
   - operations `rp_callback_committer.rb`, `rp_refresh_committer.rb`, and
     `app/models/concerns/rp_session.rb` (the `rp_base_app_*` models and the `rp_base_app` database
     entry are still present; confirm their tables in `db/rp_base_app_structure.sql`);
   - views `app/views/shared/oidc_rp_sign_entries/show.html.erb`,
     `shared/oidc_rp_sign_interruptions/show.html.erb`;
   - header: `chrome_account_navigation` and its helpers in
     `app/controllers/concerns/surface_chrome.rb`, the `<nav>` block in
     `src/layouts/SurfaceLayout.tsx`, `ChromeAccountNavigation` in `src/types/inertia.ts`, locale
     keys `layouts.shared.account_navigation.*` (still present in `config/locales`);
   - configuration: the OP origin (`boot_config` `visa_service` is still defined in
     `lib/config_values_host_family_values.rb`; the controllers read it through
     `oidc_visa_authority_host`). Name every environment variable the restored code reads; report
     names only.
2. Restore the closed set for Base App, adapted to the current tree and the four changes above.
   Restore from history rather than rewriting; change only what the current tree or this order
   requires, and say why for each change. Routes in `config/routes/base.rb`, Base App block only:
   `GET /sign`, `POST /sign`, `GET /sign/interruption`, `GET /oidc/callback`.
3. Behaviour to keep exactly (`adr/sign-neutral-entry-and-logout-target-authorization.md`,
   `adr/rp-oidc-state-and-return-target.md`, `project/browser-rp-contract.mdc`):
   - `GET /sign` renders a neutral page and creates nothing; only the CSRF-protected `POST /sign`
     starts a flow and answers 303; both are `no-store`; a signed-in browser gets 403 on both;
   - one pending flow per browser, keyed by the `state` `jti`; `state` is this RP's PS256 JWS
     carrying a path-only `target_link_uri`; PKCE `S256`; fresh `nonce`; scope as before;
   - the callback verifies `state` (signature, `iss`, `aud`, expiry, pending entry), the `iss`
     response parameter, then exchanges the code with a `private_key_jwt` assertion, verifies the ID
     token (PS256, `typ`, `iss`, `aud`, `nonce`, required claims, authentication time), commits the
     RP session in the `rp_base_app` cell and handles the Rails session at the privilege transition
     as the removed code and `project/session-issuance.mdc` require (report where the reset
     happens); expected abnormal endings land on `GET /sign/interruption` with a server-side reason
     code only; dependency failures stay 503;
   - no token, code, `state`, verifier or URL value in logs.
4. Header: on Base App, signed out, show one link labelled `sign_up_or_in` to `/sign` carrying the
   region; show nothing on the `sign`, `sign_outs` and `oidc` pages themselves. Restore for Base App
   only; do not re-add the other families' entries to `ACCOUNT_NAVIGATION_SURFACES` or
   `chrome_account_sign_in_path`. Hiding or showing a link is never authorization.

Part B: sign-out and back-channel logout (only after Part A is green).

5. Restore `sign_outs_controller.rb` with the `sign/out` termination resource as it was routed
   (`show`, `new`, `edit`, `create`) and `GET /sign/out/completion`, `oidc/closures_controller.rb`
   with `POST /oidc/closures`, and what they need (`oidc_rp_logout_launcher.rb`,
   `rp_backchannel_logout_endpoint.rb`, `oidc_op_logout_token_verifier.rb`,
   `oidc_op_revocation_client.rb`, `rp_cell_session_revoker.rb`, the `sign_out_*` concerns),
   following `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`.
   Then show the signed-in header state (sign-out link; no Base link on Base itself).

Stop on an item, record the options and continue with the rest when it needs: a schema change or
migration, a new environment variable or credential, an ADR amendment, or a contract that differs
from "Contract facts". Do not invent a substitute and do not add a fallback.

## Tests (Red first)

Restore the matching tests from history and make them fail before the code returns:
`test/controllers/base/app/oidc/callbacks_controller_test.rb`,
`test/integration/oidc_rp_browser_flow_test.rb`, `oidc_rp_default_landing_test.rb`,
`test/integration/routes/neutral_rp_entry_contract_test.rb`, `test/values/oidc_state_jwt_test.rb`,
`test/services/oidc/acme_service_origin_test.rb`, `test/operations/rp_callback_committer_test.rb`,
`test/adapters/oidc_op_token_client_test.rb`, `oidc_op_protocol_verifiers_test.rb`, the support
files they need, and for Part B `test/controllers/base/app/sign_outs_controller_test.rb` and the
`rp_backchannel_logout_*` integration tests. Drop cases that exercise other families or ceremonies.

Cover at least: GET creates no flow; POST without a CSRF token is refused; signed-in browser is
refused; the authorization URL carries exactly the expected parameters and leaves through Jump; a
second POST replaces the first pending flow and the first callback is refused; callback with
missing, tampered, expired (below, at, above expiry) and foreign-client `state`; wrong `iss`
response parameter; OP error response; token endpoint refusal versus dependency failure; ID token
signed ES384, RS256 or PS384, wrong `aud`, wrong `nonce`, wrong `typ`, expired; replayed callback;
session reset on success; header link present signed out, absent on the procedure pages. The OP is a
test double at the HTTP boundary; do not mock the verifier or committer under test. No test-only
branch in production code, no placeholder or skipped test.

## Checks and report

bin/rails zeitwerk:check, bin/rails routes (Base App block), bin/rubocop, bundle exec erb_lint
--lint-all, bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error, bundle exec
database_consistency, bun run check, the restored test files, then bin/rails test (separate
pre-existing failures from the latest evidence baseline). Add no new static-check offense
(`docs/backlog/2026-11-12-ci-static-checks-acceptance.md`). Update `README.md` (Routing and the
"sign-in is unavailable" statements), `plans/2026-11-12-handoff.md`, affected `docs/mermaid`
diagrams and checklists in the same change.

Record in evidence/YYYY-MM-DD-base-app-sign-entry-restoration-XXXX.md (full `git rev-parse HEAD`;
uncommitted changes affected results): the inventory table; files restored and each deviation from
history with its reason; routes added; environment variable and key names the owner must provision
(names only); test results; items stopped for the owner; the state of step-up; what a browser check
on `https://www.umaxica.app/` should now show (header link, `GET /sign`, `POST /sign` leaving
through Jump) and what is expected to fail until Access and Jump are ready; and confirmation that
config/credentials files are unchanged.
