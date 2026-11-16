# Public Contract Coverage Follow-up

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had **1,086 changed or untracked paths** before this evidence record was added.
The worktree contains extensive prior uncommitted changes; all runs describe that combined tree. No
commit or push was made. The changes in this slice add three test files and update the active
coverage specification. No application source, database schema/data, CI, credentials, coverage
settings, thresholds, exclusions, or source annotations changed.

## Tests added

- `test/policies/acme_quota_policy_test.rb` exercises public `remaining` and `exceeded?` results for
  active and inactive Client and Operator owners using the APP and ORG test PostgreSQL databases.
- `test/resolvers/account_standing_resolver_test.rb` calls the public resolver with the real APP and
  ORG enforcement-case model classes and confirms the no-active-case result on each database.
- `test/values/client_secret_lifetimes_value_test.rb` exercises issuance and proof-retention
  durations, zero/negative rejection, and missing required configuration through the public class
  methods. The environment is stubbed only at the `ENV.fetch` boundary; no environment construction
  is tested.

These are coverage additions for existing behavior, so no implementation defect was expected to
produce a Red run. The new tests passed without application-code changes.

## Verification

| Command                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Result                                                                                                                                                                                                                                                                                    |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `env -u COVERAGE RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test test/policies/acme_quota_policy_test.rb test/resolvers/account_standing_resolver_test.rb test/values/client_secret_lifetimes_value_test.rb` | **6 tests / 41 assertions / 0 failures / 0 errors / 0 skips**                                                                                                                                                                                                                             |
| `bin/rubocop test/policies/acme_quota_policy_test.rb test/resolvers/account_standing_resolver_test.rb test/values/client_secret_lifetimes_value_test.rb`                                                                                                                                                                                                                                                                                                                                                                                       | Passed: 3 files, 0 offenses                                                                                                                                                                                                                                                               |
| `COVERAGE=true RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test`                                                                                                                                              | **7,506 tests / 50,226 assertions / 0 failures / 0 errors / 0 skips.** Process exited 2 because the unchanged SimpleCov gates remain unmet: line **90.45% (30,128/33,307; minimum 98%)**, branch **62.15% (3,508/5,644; minimum 93%)**, and method **85.83% (4,351/5,069; minimum 97%)**. |
| `env -u COVERAGE RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test`                                                                                                                                            | **7,506 tests / 50,226 assertions / 0 failures / 0 errors / 0 skips**, exit 0                                                                                                                                                                                                             |
| `git diff --check`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Passed after the specification update                                                                                                                                                                                                                                                     |
| `scripts/check-repository-knowledge specs/test-coverage-completion/spec.md evidence/2026-11-13-coverage-public-contract-reachability-J2L6.md`                                                                                                                                                                                                                                                                                                                                                                                                  | Passed: 8 Skills/adapters, 67 documents, 1 evidence record                                                                                                                                                                                                                                |

Both full runs logged `AccessOpDataUnavailableError` from existing concurrency worker threads in
administrative access-lock and enforcement reconciliation tests. Minitest recorded no errors in
either run; the exceptions were not suppressed.

## Public/protected runtime inventory

The 17 current parallel SimpleCov resultsets were combined by source identity with the installed
`SimpleCov::Combine::MethodsCombiner`, then joined to the current runtime method inventory by source
path, line, and normalized method name. The result contains **2,576 rows**:

| Visibility         |      Rows |   Reached |  Missed | No one-to-one location | Same-line name mismatch |
| ------------------ | --------: | --------: | ------: | ---------------------: | ----------------------: |
| Public instance    |     1,603 |     1,348 |     101 |                    135 |                      19 |
| Public class       |       912 |       895 |      15 |                      0 |                       2 |
| Protected instance |        61 |        49 |      12 |                      0 |                       0 |
| **Total**          | **2,576** | **2,292** | **128** |                **135** |                  **21** |

The seven methods newly reached in this slice are:

- `Acme::AccountQuotaPolicy#remaining` and `#exceeded?`
- `Acme::OrganizationQuotaPolicy#remaining` and `#exceeded?`
- `AccountStandingResolver.call`
- `ClientSecretLifetimesValue.issuance_ttl` and `.proof_retention`

The row-level join is ignored temporary output at
`tmp/coverage-task/public-protected-joined-after-callable-tests-2026-11-13.json`. The current
runtime inventory and source/caller dispositions originate from
[`2026-11-13-coverage-reachability-L6N2.md`](2026-11-13-coverage-reachability-L6N2.md) and were
rechecked against the current source tree. The remaining **128 missed** rows are 103 controller or
controller-concern success bodies behind unavailable Access owner-data calls, and 25 non-controller
rows already classified as generated bridge predicates, retained policy hooks,
maintenance/configuration entrypoints, or methods with no current application caller. The
fail-closed request boundaries remain covered; no action body was invoked by bypassing its
authorization or owner API prerequisite. The location-less and same-line rows are not claimed as
reached.

The accepted Operator Capability ADR retains the current legacy `ApplicationPolicy` role vocabulary
for non-org callers even though no current source caller exists, so these protected methods were not
removed or forced through reflection. `Umaxica::TestEnvironment::DatabaseSafety.report` remains an
environment-construction path and was not tested through Minitest. Maintenance tasks and the
configuration-only Valkey/Turnstile methods remain explicitly classified as non-request paths.
`ClientContactAuditOutbox.record_preferences_changed!` is covered by its public-contract tests, but
the current tree still has no application preference writer; no preference workflow was invented.

No JavaScript or TypeScript source changed. The latest previously verified Vitest run remains 59
files / 588 tests at 100% statements, branches, functions, and lines. It was not rerun in this
slice.

## Completion status

- Vitest coverage threshold: met by the latest verified run; unchanged since then.
- Full Minitest behavior suite: passed with coverage enabled and disabled.
- SimpleCov aggregate thresholds: unmet and unchanged.
- Reachable public/protected coverage: seven additional methods reached; the remaining rows retain
  the cited caller/reachability dispositions. Access-owned success paths remain unavailable until
  their owner API exists.
- No database rebuild, migration, CI change, commit, or push occurred.

The coverage specification remains `implementing`; aggregate SimpleCov thresholds and the missing
preference audit writer remain open.
