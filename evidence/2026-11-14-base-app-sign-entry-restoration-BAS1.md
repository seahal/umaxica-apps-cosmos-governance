# Base App RP Sign Entry Restoration

Date: 2026-11-14 Repository: `umaxica-apps-cosmos-governance` Branch: `feature` HEAD:
`eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had 1,207 changed or untracked paths before this evidence file was added. The
worktree was not reset, stashed, or committed. `.github/workflows/ci.yml` was already modified when
this task began and was not edited by this task. No credentials, schema source, or migration was
edited. No commit, push, deployment, external request, or production/shared database operation was
made.

## Inventory and implementation

The inventory compares the named files at `eedf4f51e~1` with the current worktree, as required by
the work order. All listed historical files existed at that checkpoint.

| Paths                                                                                                                                                                                                       | At checkpoint | Current | Dependency or disposition                                                                                                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app/controllers/base/app/sign/{entries,interruptions}_controller.rb`, `app/controllers/base/app/oidc/callbacks_controller.rb`                                                                              | Present       | Present | Restored the passive entry, CSRF-protected start, server-reason interruption, and protocol callback. Requires the OIDC entry/callback concerns, state value, Visa origin, token client, verifier, local committer, and views.                                                                                             |
| `app/controllers/base/app/sign_outs_controller.rb`, `app/controllers/base/app/oidc/closures_controller.rb`                                                                                                  | Present       | Present | Restored Base App local sign-out and the POST back-channel receiver. Requires the notice adapter, logout launcher/verifier, revocation client, and RP session revoker.                                                                                                                                                    |
| `oidc_rp_sign_entry.rb`, `oidc_rp_sign_interruption.rb`, `oidc_sso_initiator.rb`, `oidc_callback.rb`                                                                                                        | Present       | Present | Reconnected the state-indexed pending flow, PS256 state, PKCE S256, callback validation and local commit.                                                                                                                                                                                                                 |
| `browser_rp_safe_request_refresh.rb`                                                                                                                                                                        | Present       | Absent  | Not reconnected: safe-request refresh and `prompt=none` recovery are outside this order's entry/callback/sign-out/BCL boundary and their refresh rotation contract is not in the supplied Access facts. No current application caller remains.                                                                            |
| `oidc_rp_logout_launcher.rb`, `rp_backchannel_logout_endpoint.rb`, `sign_out_notice.rb`                                                                                                                     | Present       | Present | Local revocation commits before cookie/session reset and Jump handoff; the BCL path verifies, tombstones and records replay state before acknowledgement.                                                                                                                                                                 |
| `oidc_state_jwt.rb`, `oidc/acme_service_origin.rb`, `oidc_op_token_client.rb`, `oidc_op_id_token_verifier.rb`, `oidc_op_logout_token_verifier.rb`, `oidc_op_revocation_client.rb`, `oidc_op_jwks_client.rb` | Present       | Present | Restored the Base App protocol dependencies using PS256 and the configured Visa origin. Authorization-code exchange and revocation require `private_key_jwt`.                                                                                                                                                             |
| `rp_callback_committer.rb`                                                                                                                                                                                  | Present       | Present | Commits identity binding, OP SID binding and local session in `rp_base_app` before the Rails session reset.                                                                                                                                                                                                               |
| `rp_refresh_committer.rb`, `app/models/concerns/rp_session.rb`                                                                                                                                              | Present       | Absent  | The old refresh committer is outside this order's stated boundary. The old `RpSession` concern depends on shared OP grant/root-token and cross-database parent-token behavior; the current Governance RP session is local to `rp_base_app`. Restoring it would reintroduce retired ownership and cross-database behavior. |
| `app/views/shared/oidc_rp_sign_entries/show.html.erb`, `oidc_rp_sign_interruptions/show.html.erb`                                                                                                           | Present       | Present | Restored the neutral page and generic interruption page. No token or code is rendered.                                                                                                                                                                                                                                    |
| `surface_chrome.rb`, `SurfaceLayout.tsx`, `inertia.ts`, `config/locales/{en,ja}.yml`                                                                                                                        | Present       | Present | Added only the Base App signed-out entry link and Base App signed-in sign-out link. Procedure pages hide account navigation. Full RuboCop formatting was applied to the changed navigation block.                                                                                                                         |
| `config/routes/base.rb`, `db/rp_base_app_structure.sql`                                                                                                                                                     | Present       | Present | Added routes only. The existing RP Base App structure was used; there is no schema or migration change.                                                                                                                                                                                                                   |

The uncalled `OidcOpTokenClient.refresh` public class method was removed after a repository-wide
search found no caller. It was not needed by the accepted authorization-code, sign-out, or BCL
flows. No refresh path was retained as an untested public entry point.

The registered Base App routes are:

```text
GET  /sign
POST /sign
GET  /sign/interruption
GET  /oidc/callback
GET  /sign/out
GET  /sign/out/new
GET  /sign/out/edit
POST /sign/out
GET  /sign/out/completion
POST /oidc/closures
```

The route list contains no Base Org or Tech OIDC callback, ceremony, or setup route. The
`/verification/oidc/callback` step-up route remains absent and step-up behavior was not restored.

## Contract and documentation

- State signing and ID/Logout Token verification are PS256-only. `OidcOpIdTokenVerifier` supplies
  the clock-skew leeway. The authorization URL goes through Jump; it does not include `prompt` or
  `max_age`.
- On successful callback, `RpCallbackCommitter` completes the RP database transaction first;
  `install_authenticated_session!` then calls `reset_session` before installing browser cookies.
- Signed-out HTML shows one Base App “sign up or sign in” link to `/sign` with the region. GET
  `/sign` creates no flow; POST requires Rails CSRF and answers through Jump. Signed-in browsers are
  refused. Callback failures use a server-side reason code and the generic interruption route.
- Sign-out commits local revocation before clearing credentials and leaving through Jump. BCL stores
  an unknown-SID tombstone and a replay receipt in the RP cell.
- Current docs updated in the combined worktree include `README.md`, `plans/2026-11-12-handoff.md`,
  and `docs/checklists/session-management.md`. The existing
  `docs/mermaid/rp-base-app-session-lifecycle.mmd` and
  `docs/mermaid/rp-base-app-session-transition-inventory.md` already describe the current callback,
  local sign-out, BCL and tombstone transitions; they were checked against the restored writers and
  required no further edit.
- Relevant decisions checked: `adr/sign-neutral-entry-and-logout-target-authorization.md`,
  `adr/rp-oidc-state-and-return-target.md`,
  `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`,
  `adr/op-auth-rp-authentication-responsibility-separation.md`,
  `.agents/harnesses/rules/project/browser-rp-contract.mdc`, and
  `.agents/harnesses/rules/project/session-issuance.mdc`.

No new environment variable or credential was added. Existing configuration names used by the
restored path and its Jump/JWT boundaries are recorded here by name only: `VISA_SERVICE_URL` or
`PUBLIC_VISA_SERVICE_URL`, `PUBLIC_BASE_SERVICE_URL`, `PRIVATE_JUMP_GATEWAY_URL`,
`PUBLIC_JUMP_GATEWAY_URL`, `JUMP_RETURN_REVOKED_KIDS`, `JUMP_RT_TTL_SECONDS`,
`AUTH_JWT_PRIVATE_KEYSET`, `AUTH_JWT_PUBLIC_KEYSET`, `AUTH_JWT_ACTIVE_KID`, `AUTH_JWT_REVOKED_KIDS`,
`UMAXICA_RUNTIME_ROLE`, and `UMAXICA_RP_BROWSER_ADMISSION`. The OP signing key namespace is
`BASE_RP_APP_WW`. Values were not read into this report.

Access `/oauth/authorize` is still known to answer 503; a real sign-in cannot complete until Access
reopens it. Jump's deployed trust and JWKS state were not checked from this repository-only
environment. No browser or network check was made. Once Access and Jump are ready, a browser check
should see the single header link, a passive `GET /sign`, and a CSRF-protected `POST /sign` leaving
through Jump. Completion is expected to remain unavailable until Access and Jump are ready.

## TDD and verification

Earlier Red/Green slices recorded during implementation:

- Part A's restored entry/callback tests first reported **14 runs / 7 assertions / 4 failures / 10
  errors**. The first implementation pass reported **14 / 49 / 0 failures / 1 error**; that setup
  error was addressed in the subsequent focused run.
- Part B's first restored suite reported **16 runs / 1 failure / 15 errors**. A later focused Red
  run was **11 / 48 / 2 failures** and its Green run **12 / 66 / 0 failures**. The concurrency
  regression was **1 / 2 / 1 failure**, then **1 / 6 / 0 failures** after correction.
- Base App local-auth fixture tests initially reported **8 runs / 26 assertions / 5 failures**: Base
  App test credentials and seeded bindings used the retired Base-host issuer/JWKS instead of the
  supplied Visa issuer/JWKS contract. After correcting those fixtures, they reported **8 / 54 / 1
  failure**; the remaining failure is the out-of-scope step-up request described below.
- Header/sign-out/neutral-entry tests passed **18 runs / 170 assertions**. Authorization-code token
  client tests passed **2 runs / 13 assertions**.
- The 22-file focused RP suite reported **85 runs / 517 assertions / 1 failure**. Its sole failure
  was
  `BaseSharedRpCellSelectionTest#test_shared_Base_APP_accepts_only_its_live_local_RP_session_and_refuses_missing_Access_issuance`:
  the test expects 503 for the step-up start while the current out-of-scope implementation
  returns 409. The step-up code and assertion were left unchanged.

Final checks after the last source change:

| Check                                                             | Result                                                                                            |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `bin/rails zeitwerk:check`                                        | Passed: “All is good!”                                                                            |
| `bin/rails routes`                                                | Passed; the ten Base App routes above were present.                                               |
| `bin/rubocop`                                                     | Passed: 2,860 files, zero offenses.                                                               |
| `bundle exec erb_lint --lint-all`                                 | Passed: no ERB errors.                                                                            |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`  | Passed: zero warnings.                                                                            |
| `bun run check`                                                   | Passed.                                                                                           |
| `git diff --check`                                                | Passed.                                                                                           |
| `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency` | Exit 1 with one unchanged finding: `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`. |

Full Rails runs on the combined worktree each contained 7,582 tests. The standard parallel run was
**50,710 assertions / 8 failures / 0 errors / 0 skips**. The serial run was **50,704 assertions / 10
failures / 0 errors / 0 skips**. The final coverage run was **50,714 assertions / 7 failures / 0
errors / 0 skips**. All seven failures in the final run are step-up tests, which this order
explicitly excludes: `BaseSharedRpCellSelectionTest`, `BaseStepUpIntentAuthorityTest`,
`BaseStepUpStartTest`, `StepUpCeremonyObservabilityTest`, and the Base App Passkeys, TOTP and
withdrawal step-up tests. The additional failures in the other two full runs were not reproducible
in isolation: preference/CSRF/CSP checks passed **46 / 1,215 / 0 failures**, and CSRF notification
checks passed **5 / 21 / 0 failures**. The full suite is therefore not reported as passing.

The final fixture run changed three migration-owned test catalogs. Only the disposable test writers
`app_setting`, `org_setting`, and `occurrence` were verified to have no other sessions, then
individually dropped, recreated and migrated. The final read-only catalog check found **16 test
writers / 79 NOT VALID FKs / 0 NOT VALID CHECKs**; migration receipt counts were **17**, **17**, and
**118**, respectively. No test ran after this reconstruction.

## Remaining decisions and risks

- Safe browser refresh (`browser_rp_safe_request_refresh` / `rp_refresh_committer`) remains outside
  this restoration boundary. If it is required for Base App availability, the owner must define the
  Access refresh-rotation/refusal contract and authorize that follow-up. Reusing the old
  `prompt=none` behavior without that contract risks replaying a rotated token or claiming a session
  remains usable when Access has revoked it.
- Access authorization and deployed Jump trust remain external prerequisites. Step-up remains
  unchanged and its full-suite failures are reported above.
- There was no schema change, so no migration or database table/constraint/index was added or
  altered by this task. Test-only DB reconstruction restored the existing migration-owned state.
- During an earlier diagnostic, a nonsecret test database preparation list and test-generated
  signed-token values appeared in tool output. They are not reproduced here; no real credential or
  key material was accessed. Temporary diagnostic logs created for this task are removed after
  evidence is recorded.

No commit or push was made.
