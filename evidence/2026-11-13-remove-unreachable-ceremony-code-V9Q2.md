# Remove Unreachable Ceremony Code — Final Current-Tree Result

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

After the preceding CI work-order evidence, the shared worktree had 1,019 changed or untracked
paths. The final observed count is 1,070. The result describes the combined dirty tree. Several
model files edited here already had unrelated in-progress changes; those changes were preserved.
`.github/workflows/ci.yml` was already modified and was not touched. Credentials were not changed.
The worktree also already contains unrelated Chronicle schema/migration changes; this ceremony pass
did not edit `db/`, change a schema, or reset a database. No commit, push or deployment was made.

This is the final continuation of the removal recorded in
`2026-11-13-remove-unreachable-ceremony- code-Q7M2.md`, `C5P2.md`, `D4M8.md`, `N4C7.md`, `R8K2.md`
and `Z8M6.md`. Later coverage and dead-method review is in
`2026-11-13-coverage-reachability-L6N2.md`. CI static-check results immediately before this pass are
in `2026-11-13-ci-static-checks-zero-T5C8.md`.

## Ownership and current-tree audit

The owner decision is that Access runs OpenID Provider authentication ceremonies; Governance keeps
identity and credential records, its RP state and its OIDC handoff boundary. The starting-list
searches and broader dynamic-name searches in Q7M2/Z8M6 found no current application callers for the
retired sign-in/sign-up/admission/OP-result families. A final source search across `app/`, `lib/`,
`config/`, `db/`, `test/`, `src/` and `gait/` found no remaining definitions or references for the
removed model API methods, `SensitiveAdmission`, or the removed ceremony symbols. Remaining
`sign_up_flow_ref` and claim fields are stored historical/ownership facts; this pass did not remove
their columns, validation or persisted values.

The final continuation removed additional unreachable code:

- Removed `Client#finalize_email_sign_up!` and `#finalize_telephone_sign_up!`,
  `ClientTelephone#finalize_sign_up_binding!`, the old Email and Telephone contact-finalization
  stubs, `OperatorEmail#finalize_email_registration!`,
  `OperatorTelephone#finalize_telephone_registration!`, `ClientRegistrationCompletion#verify_flow!`,
  and `ClientSecretCredential#commit_sign_in_claim!` / `#commit_sign_in_retirement!`. These methods
  had no application caller; references were limited to tests that invoked the methods directly.
  Their bodies only raised `AccessOpDataUnavailableError`. Those stub-only assertions were removed
  with the APIs. The record models and lifecycle, retention, ownership and database protections
  remain.
- Removed the unused `ClientRegistrationCompletion::Conflict` class. No reference existed outside
  its definition.
- Removed the write-authority branch backed by `@authentication_fact_write`; no code assigned that
  flag. Persisted authentication-claim fields remain unconditionally read-only through the existing
  model and SQL write guards.
- Removed the unreferenced `SensitiveAdmission` concern. It had no includer or reader.
- Removed 44 unreferenced provider-brand assets: four files under `public/images/social/` and 40
  Apple sign-in source assets under `src/assets/brand/sign-in-with-apple/`. No source reference,
  import, or asset glob named these paths. Activity/audit labels and `ClientSocialLinkSourceReceipt`
  remain because they describe retained history and owner data, not a local social callback.
- Marked `adr/realm-separated-identifiers-and-dead-history.md` as partially superseded for
  Governance runtime, and marked `plans/backlog/2026-11-05-contact-sign-up-registered-identifier.md`
  superseded for local implementation. Historical requirements were preserved with the supersession
  status; the backlog no longer presents old local ceremony code as current work.

The remaining appeal-resolution boundary in `test/models/access_op_model_boundary_test.rb` was kept:
its live caller is
`app/controllers/base/org/api/v0/support/enforcement_cases/appeal_reviews_controller.rb:60`.
Retained Governance entry points that still depend on Access continue to fail closed. Existing
request/integration tests cover unavailable responses for APP/ORG authority APIs and step-up starts;
for example `test/integration/base_access_authority_api_unavailable_test.rb` and
`test/integration/base_step_up_start_test.rb`. Credential inventory/management, withdrawal and
enforcement lifecycles, RP state/audit, server-to-server lookup/revocation boundaries and owner
records remain. `CoreRpBridge` remains for its two live client/operator bridge inclusions; its
retired `actor`, `subject`, `core?` and foreign-key API remain absent.

No new table, column, index, constraint, structure dump, row or migration was removed or changed. No
new readerless table was identified: the deleted APIs only raised and did not read or write a table.
Existing retained registration-completion, Secret, credential, RP-state, audit, withdrawal,
external-identity and source-receipt records remain for their ownership/history contracts.

## Historical material retained

- `specs/op-mediated-step-up/spec.md`,
  `specs/op-mediated-step-up/contracts/lock-order-inventory.md`, and
  `specs/op-mediated-step-up/contracts/o9-visa-roundtrip-design.md` carry explicit 2026-11-13 owner
  supersession notes. Their Governance-local Auth/Visa flows are historical; retained RP and handoff
  requirements remain distinct.
- Visitor/COM identity diagrams remain in `docs/mermaid/archive/visitor-com-retired/`; the archive
  path labels them as retired. No active Mermaid diagram describes a Governance-local authentication
  ceremony.
- `research/2026-10-22-test-value-audit/` inventories, prior evidence, migration history and other
  dated design records keep old source references as provenance. They are not current callers.
- Current security/checklist documents that previously contradicted the split were updated or
  superseded in the earlier ceremony work, as itemized in Q7M2/Z8M6. This pass did not rewrite
  historical research or evidence.

## Verification

Focused model tests used the explicit `test_*` writer catalog from `config/ci.rb`; the full runs
also included `test_queue_db` because the repository test suite uses it. All connections were
test-prefixed. No test database was dropped or recreated during this continuation. The exact
`POSTGRESQL_TEST_PREPARE_DATABASES` value was
`test_primary_db,test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_com_setting_db,test_org_setting_db,test_app_signal_db,test_org_signal_db,test_avatar_db,test_chronicle_db,test_occurrence_db,test_queue_db,test_storage_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db`.

| Command                                                                                           | Result                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Focused contact, Secret, registration-completion and retained Access-boundary tests               | 131 tests / 555 assertions / 0 failures / 0 errors / 0 skips                                                                                                                                                                                                       |
| `env -u COVERAGE RAILS_ENV=test bin/rails test` with the exact writer list above                  | 7,492 tests / 50,156 assertions / 0 failures / 0 errors / 0 skips                                                                                                                                                                                                  |
| `COVERAGE=true RAILS_ENV=test bin/rails test` with the exact writer list above                    | Same 7,492 tests / 50,156 assertions, no test failures/errors/skips; command exited 2 only because SimpleCov thresholds were unmet: line 90.37% (30,098/33,304; minimum 98%), branch 62.03% (3,501/5,644; minimum 93%), method 85.57% (4,338/5,069; minimum 97%)   |
| Prior coverage before this final deletion, `2026-11-13-coverage-reachability-L6N2.md`             | 7,499 tests / 50,191 assertions; line 90.37%, branch 62.01%, method 85.62%, also below configured thresholds                                                                                                                                                       |
| `RAILS_ENV=test bin/rails zeitwerk:check`                                                         | Passed: `All is good!`                                                                                                                                                                                                                                             |
| `RAILS_ENV=test bin/rails routes`                                                                 | Passed; 429 output lines. Retired local sign-in/sign-up/social callback routes are absent; owner credential-management routes remain.                                                                                                                              |
| `bin/rubocop`                                                                                     | Passed: 2,815 files, 0 offenses                                                                                                                                                                                                                                    |
| `bundle exec erb_lint --lint-all`                                                                 | Passed: 1,510 files, 0 errors                                                                                                                                                                                                                                      |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                  | Passed: 0 warnings, 0 errors                                                                                                                                                                                                                                       |
| `bun run check`                                                                                   | Passed format, lint, typecheck, dead-code and OpenAPI checks; the existing Knip compiled-CSS hint remains                                                                                                                                                          |
| Isolated `VITE_RUBY_PUBLIC_OUTPUT_DIR` production build                                           | Passed; Vite generated a manifest and assets. The existing React Compiler skipped `CookieBanner` because its `try/finally` control flow is unsupported. The uniquely named temporary output directory was removed after inspection; `public/vite` was not changed. |
| `RAILS_ENV=test bundle exec database_consistency`                                                 | Exit 1 with the same one `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted` expression-index finding recorded in T5C8; no checker configuration or exclusion was added                                                                                  |
| `git diff --check`                                                                                | Passed after the final code and documentation edits                                                                                                                                                                                                                |
| `scripts/check-repository-knowledge evidence/2026-11-13-remove-unreachable-ceremony-code-V9Q2.md` | Passed: 8 Skills/adapters, 66 documents, 1 evidence record                                                                                                                                                                                                         |

The run count is seven below the preceding 7,499-run coverage record, matching the seven direct
stub-only test methods removed from `AccessOpModelBoundaryTest`. Thirty-two assertions were removed
with those tests and the two removed Secret stub calls; the final assertion count is 35 below the
previous run. Three assertions of that difference are not attributable from the combined worktree;
parallel test runs have previously varied slightly in assertion count. The stated 7,657 baseline is
also from an earlier tree and is not a like-for-like source/test inventory.

## Final status

- Unreachable Governance ceremony code and its stub-only APIs were removed; retained real callers
  and ownership records remain.
- Existing fail-closed paths continue to have explicit boundary tests. No unavailable OP path was
  changed to return an empty success or use a local fallback.
- No schema or persisted data was removed. No production/shared database was accessed, and the
  current test databases were not reset.
- The final evidence record passes the repository knowledge checker and `git diff --check`.
- SimpleCov remains below its existing minima although every test passed. The one
  DatabaseConsistency expression-index finding remains separately recorded in T5C8.
- Credentials are unchanged. `.github/workflows/ci.yml` remains pre-existing and untouched. No
  commit or push was made.
