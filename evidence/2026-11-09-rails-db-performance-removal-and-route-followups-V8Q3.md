# RailsDb and RailsPerformance retirement and route-separation follow-up

Date: 2026-11-09

## Revision and worktree

- `git rev-parse HEAD`: `43db4906742db2fb13b238c9ccde378e4e1583b4`.
- The worktree was already dirty and included unrelated edits. Verification ran against that shared working tree. No commit was created, and unrelated TODO/NOTICE/NOTE/FIXME comments, MessagePack changes, and ADR/docs/plans changes were preserved.

## RailsDb and RailsPerformance

- Removed `rails_db` and `rails_performance` from the Gemfile and ran `bundle install --local`. The lockfile only lost those gems and dependencies that no longer had a consumer; no dependency was added or upgraded. MessagePack remains.
- Removed the RailsDb and RailsPerformance routes, engine setup and RailsPerformance-only initializer, sanitization/resilience code, host registration and isolated tests. Kept `/rails/db` and `/rails/performance` in the forbidden mount paths.
- Removed four RailsPerformance assignments from the tracked `.env.container.devcontainer` template without displaying or recording their values. Updated the operator-tools documentation and the Coverband comment in `compose.yaml`.
- Updated `test/integration/routes/app_rails_edge_ownership_contract_test.rb` to stop expecting the retired `performance` draw.
- Development route inspection found neither retired route. Requests to the two old RailsPerformance hosts returned 404. The RailsDb host probe returned 404 for 23 candidate hosts, 401 for 10 tool-host requests, and 403 for 2 host-pattern requests; therefore, the probe did not establish a universal 404 response even though the development route table contains no `/rails/db` route.
- `.github/workflows/ci.yml` and `.devcontainer/compose.yaml` were read-only in this workspace, so their RailsPerformance CI variable entries and `rails_performance` alias remain. Writes failed with `EROFS`; no workaround was attempted. No Cloudflare, DNS, tunnel, Access-policy or other external change was made.
- The existing RailsDb backlog also calls for removing the gem from running development containers. This work did not recreate containers or alter their volumes.

## Test comparison and the 23 prior new failures

The prior comparison is [M6H2](2026-11-09-governance-route-separation-cleanup-M6H2.md); the pre-separation baseline is [G7Q2](2026-11-09-governance-route-separation-baseline-G7Q2.md). The final command was `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`.

- Final full suite: 14,481 runs, 108,934 assertions, 131 failures, 24 errors, 0 skips.
- 109 failure IDs and all 24 error IDs match the pre-separation baseline. There are 22 new failure IDs and no new errors. There are no additional new IDs outside the M6H2 list.
- Of the 23 M6H2 new failures, one Auth-only test was removed because it directly called a route owned by the removed Auth surface. The remaining 22 all still fail. Every row below is a failure (not an error); row numbers refer to M6H2 to avoid copying test titles that contain fixture-like credential values.

| M6H2 row | First repository line | Classification | Reason / disposition |
|---:|---|---|---|
| 185 | `test/integration/anonymous_com_web_push_initialization_test.rb:609` | (c) Other | Com Web Push initialization assertion; the Com route remains and the failure does not reference a removed surface. Left unchanged. |
| 186 | `test/integration/anonymous_com_web_push_initialization_test.rb:578` | (c) Other | Com Web Push cookie/header assertion; the route remains. Left unchanged. |
| 187 | `test/controllers/base/identity_sessions_presentation_test.rb:24` | (b) Base App local-cell pending | Base App session presentation redirects because the local RP session path is not ready. |
| 188 | `test/controllers/base/identity_sessions_presentation_test.rb:58` | (c) Other | Base Org session presentation; its route remains and this is not the deferred Base App local-cell path. Left unchanged. |
| 189 | `test/controllers/base/org/identity/rp_root_feature_refusal_test.rb:76` | (c) Other | Base Org root-token refusal is on a retained route. RP-cell root-token ownership is an unresolved owner decision in `plans/backlog/2026-11-04-base-rp-cell-root-token-features.md`. |
| 190 | `test/controllers/csp_violation_reports_controller_test.rb:41` | (c) Other | The Base CSP intake route remains; the assertion concerns its response headers. Left unchanged to preserve the current CSRF/cookie boundary. |
| 191 | `test/integration/email_delivery_test.rb:48` | (a) Separation-caused; fixed | The test called the removed Auth route helper directly. Deleted the Auth-only test file; it is absent from the final suite. |
| 192 | `test/integration/rp_cell_local_session_readiness_test.rb:54` | (c) Other | Base Org local sign-out readiness, not the deferred Base App work. Left unchanged. |
| 193 | `test/integration/tech_org_access_revocation_test.rb:74` | (c) Other | Tech revocation behavior on a retained Tech route. Left unchanged. |
| 194 | `test/integration/tech_org_access_revocation_test.rb:61` | (c) Other | Tech refresh behavior on a retained Tech route. Left unchanged. |
| 198 | `test/controllers/concerns/browser_rp_authentication_test.rb:788` | (b) Base App local-cell pending | Base App RP authentication cannot yet resolve the local session/authority path. |
| 199 | `test/controllers/concerns/browser_rp_authentication_test.rb:788` | (b) Base App local-cell pending | Same Base App local-session dependency. |
| 200 | `test/controllers/concerns/browser_rp_authentication_test.rb:788` | (b) Base App local-cell pending | Same Base App local-session dependency. |
| 201 | `test/controllers/concerns/browser_rp_authentication_test.rb:535` | (b) Base App local-cell pending | Refresh/revocation behavior depends on the unfinished Base App RP-local session binding. |
| 202 | `test/controllers/concerns/browser_rp_authentication_test.rb:180` | (b) Base App local-cell pending | Base App protected-request authentication depends on the unfinished RP-local session path. |
| 203 | `test/controllers/concerns/browser_rp_authentication_test.rb:202` | (b) Base App local-cell pending | Base App refresh behavior depends on the unfinished RP-local session path. |
| 204 | `test/controllers/concerns/browser_rp_authentication_test.rb:1007` | (b) Base App local-cell pending | Base App invalid-refresh handling depends on the unfinished RP-local session path. |
| 205 | `test/controllers/concerns/browser_rp_authentication_test.rb:962` | (b) Base App local-cell pending | Base App refresh refusal depends on the unfinished RP-local session path. |
| 206 | `test/controllers/concerns/browser_rp_authentication_test.rb:298` | (b) Base App local-cell pending | Base App refresh-and-mutation ordering depends on the unfinished RP-local session path. |
| 207 | `test/integration/rp_cell_local_session_readiness_test.rb:54` | (b) Base App local-cell pending | Base App local sign-out returns the unavailable-cell response. |
| 211 | `test/controllers/base/app/verification/setups_controller_test.rb:225` | (b) Base App local-cell pending | Verification bootstrap lacks an agreed OP authority anchor for the RP process; see `plans/backlog/2026-11-03-base-verification-setup-bootstrap-rp-cell.md`. |
| 212 | `test/controllers/base/app/verification/setups_controller_test.rb:264` | (b) Base App local-cell pending | Same missing verification-bootstrap authority contract. |
| 213 | `test/integration/oidc_rp_logout_edit_return_test.rb:82` | (c) Other | Base staff RP logout to the Visa staff OP; the endpoint remains and this does not depend on the removed Edit surface. Left unchanged. |

Classification totals: (a) 1 fixed, (b) 13 deferred to Base App local-cell work, (c) 9 left unchanged. For (b), the missing work is RP-local session issuance/lookup and OP-to-RP session binding/closure, a decision on OP root-token ownership where required, and an agreed verification-bootstrap authority anchor. No fix was made to those deferred workflows.

## Verification

- `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=test bin/rails test test/security`: 126 runs, 748 assertions, 3 failures, 0 errors. All three match baseline failures: `test/security/invariants/withdrawal_gate_invariant_test.rb:35`, `test/security/invariants/withdrawal_gate_invariant_test.rb:67`, and `test/security/invariants/org_withdrawal_gate_invariant_test.rb:52`.
- `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=test bin/rails test test/integration/routes/app_rails_edge_ownership_contract_test.rb`: 3 runs, 20 assertions, 0 failures, 0 errors.
- `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=test bin/rails test test/security/invariants/mounted_engine_invariant_test.rb`: 5 runs, 19 assertions, 0 failures, 0 errors.
- `bin/rubocop`: 4,686 files inspected, no offenses.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: 0 errors, 0 security warnings.
- `git diff --check`: passed.

## Development reference rows and initializer side effect

The read-only audit found 121 missing fixed-ID state rows across the 17 tables below. After the owner instructed me to finish the remaining work, I treated that instruction as approval to insert exactly this previously listed set. The inserts followed the repository migration/seed definitions; only `id` was inserted except for the two session-limit state tables, which also received `created_at` and `updated_at` as required by `db/seeds.rb`.

| Development database | Table | Missing IDs |
|---|---|---|
| `op_base_app` | `client_sign_in_flow_states` | 10, 20, 30, 40, 50, 60, 65, 70, 80, 100, 900, 910, 920, 930 |
| `op_base_app` | `client_sign_up_flow_statuses` | 10, 20, 30, 35, 36, 38, 40, 60, 70, 80, 100, 900, 910, 920, 930 |
| `op_base_app` | `client_sign_up_flow_cleanup_statuses` | 0, 10, 20, 30, 40 |
| `op_base_app` | `client_session_limit_resolution_states` | 10, 20, 100, 910, 920 |
| `op_base_app` | `client_auth_admission_binding_statuses` | 10, 20, 30, 40, 90, 91 |
| `op_base_app` | `client_auth_ceremony_session_statuses` | 10, 20, 30, 40, 90, 91, 92, 93 |
| `op_base_app` | `client_oidc_authorization_transaction_statuses` | 10, 20, 30, 90 |
| `op_base_org` | `operator_sign_in_flow_states` | 10, 20, 30, 40, 50, 60, 65, 70, 80, 100, 900, 910, 920, 930 |
| `op_base_org` | `operator_sign_up_flow_statuses` | 10, 20, 30, 40, 100, 900, 910, 920, 930 |
| `op_base_org` | `operator_session_limit_resolution_states` | 10, 20, 100, 910, 920 |
| `op_base_org` | `operator_auth_admission_binding_statuses` | 10, 20, 30, 40, 90, 91 |
| `op_base_org` | `operator_auth_ceremony_session_statuses` | 10, 20, 30, 40, 90, 91, 92, 93 |
| `op_base_org` | `operator_oidc_authorization_transaction_statuses` | 10, 20, 30, 90 |
| `rp_base_app` | `rp_step_up_state_statuses` | 10, 15, 20, 90, 91, 92, 93 |
| `rp_base_app` | `rp_step_up_audit_outbox_delivery_states` | 10, 20 |
| `rp_base_org` | `rp_step_up_state_statuses` | 10, 15, 20, 90, 91, 92, 93 |
| `rp_base_org` | `rp_step_up_audit_outbox_delivery_states` | 10, 20 |

The first write attempt failed during row validation before any transaction committed. A new read-only query confirmed the same 121 rows were still missing. The retry opened a transaction on each of the four development databases, inserted only the approved IDs with `ON CONFLICT (id) DO NOTHING`, verified each requested ID before commit, and committed after all four databases passed validation. Result: 121 inserted and 121/121 present on the post-commit read-only verification; remaining missing count 0. No database creation, reset, deletion, or unrelated seed operation was run. If validation had failed before commit, all open transactions were rolled back.

During earlier Rails development route/server inspection, `config/initializers/preference_reference_defaults.rb` may have inserted defaults into nine preference reference tables. The current read-only counts are 2 rows in each of the three preference-status tables; 2 rows in each of the three Chronicle-level tables; and 14, 15, and 14 rows in the App, Com, and Org Chronicle-event tables. There was no pre-start count, so the number of rows added by those boots cannot be established. No rollback or deletion was attempted. Further development Rails boots were avoided.

The expected Access checkout and its route-separation evidence were unavailable at the supplied path in this workspace. The local read-only database procedure therefore used the Governance repository's existing reference-data research and migrations.

## Continuation audit

After the follow-up instruction to finish, a separate read-only audit reconfirmed all 121 expected rows remain present across the 17 tables. `statvfs` still reports `.github/workflows/` and `.devcontainer/` mounted with `ST_RDONLY`; `.github/workflows/ci.yml` retains five RailsPerformance environment keys in each of two workflow sections, and `.devcontainer/compose.yaml` retains one `rails_performance` alias. The existing `.devcontainer/compose.yaml` worktree changes were preserved. No safe write path to either file was available.

## Remaining work

- Make the RailsPerformance CI and dev-container alias removals in `.github/workflows/ci.yml` and `.devcontainer/compose.yaml` when those files are writable.
- Confirm all RailsDb public-host responses and recreate running development containers as appropriate; this workspace did not change containers or external access controls.
