# Public/Protected Coverage — Final Current-Tree Recheck

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had 1,082 changed or untracked paths before this evidence was added. The
coverage run describes that combined tree. Since the preceding coverage record
[`2026-11-13-coverage-public-protected-revalidation-J8V4.md`](2026-11-13-coverage-public-protected-revalidation-J8V4.md),
the only test changes were replacing ten scanner-matched static Avatar transfer UUID fixtures with
`SecureRandom.uuid`. The UUID-v4 contract and all assertions remain. No application source, database
schema, CI, credentials, coverage configuration, threshold, exclusion, source ignore, commit, or
push changed in this recheck.

## Full-suite verification

| Command                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Result                                                                                                                                                                                                                                                                      |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `COVERAGE=true RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test`                                                                                            | **7,500 tests / 50,188 assertions / 0 failures / 0 errors / 0 skips.** Process exited 2 only because SimpleCov remained below existing gates: line **90.42% (30,119/33,307; min 98%)**, branch **62.11% (3,506/5,644; min 93%)**, method **85.69% (4,344/5,069; min 97%)**. |
| `env -u COVERAGE RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test`                                                                                          | **7,500 tests / 50,185 assertions / 0 failures / 0 errors / 0 skips.** Several existing concurrency tests printed `AccessOpDataUnavailableError` worker-thread traces; Minitest recorded no failures or errors.                                                             |
| `env -u COVERAGE RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test test/models/avatar_transfer_reservation_test.rb test/models/avatar_transfer_source_retention_test.rb` | **26 tests / 111 assertions / 0 failures / 0 errors / 0 skips.**                                                                                                                                                                                                            |
| `bin/rubocop test/models/avatar_transfer_reservation_test.rb test/models/avatar_transfer_source_retention_test.rb`                                                                                                                                                                                                                                                                                                                                                                           | Passed: 2 files, 0 offenses.                                                                                                                                                                                                                                                |

The three-assertion difference between coverage and coverage-disabled runs is unexplained; both runs
executed the same test count with no Minitest failures, errors, or skips. The full-run output
included concurrency worker reports from existing Access-unavailable test paths; these were not
suppressed. The test writer catalog includes `test_queue_db` because the Rails test harness uses it;
no Queue schema or implementation was changed.

## Current public/protected inventory

The latest runtime method rows were joined to all **17** current SimpleCov resultsets with the
installed `SimpleCov::Combine::MethodsCombiner`. The row counts are unchanged from J8V4:

| Visibility         |      Rows |   Reached | Uncovered | No one-to-one location | Same-line name mismatch |
| ------------------ | --------: | --------: | --------: | ---------------------: | ----------------------: |
| Public instance    |     1,603 |     1,344 |       105 |                    135 |                      19 |
| Public class       |       912 |       892 |        18 |                      0 |                       2 |
| Protected instance |        61 |        49 |        12 |                      0 |                       0 |
| **Total**          | **2,576** | **2,285** |   **135** |                **135** |                  **21** |

`ClientContactAuditOutbox.record_preferences_changed!` and `CredentialDeletionFinalizer.register`
remain reached. The 135 uncovered method identities retain the per-method dispositions in
[`2026-11-13-coverage-reachability-L6N2.md`](2026-11-13-coverage-reachability-L6N2.md): unavailable
Access-owned success bodies, maintenance/configuration entrypoints, and methods with no current
application caller. The 135 rows without one-to-one locations and 21 same-line name mismatches are
not counted as covered. No reflection or synthetic test-only product path was added. The absence of
an application preference-audit writer remains a separate owner/workflow discrepancy.

The latest frontend coverage remains the previously verified 59 files / 588 tests at 100%
statements, branches, functions, and lines; no JavaScript or TypeScript source changed. The
full-suite inventory artifacts are ignored temporary outputs under `tmp/coverage-task/`.

The behavior Red/Green observation for exception-safe browser RP cookie deletion, its focused
request tests, the database model public-contract tests, and the repository-knowledge check are
recorded in J8V4. The separate current Gitleaks reduction is in
[`2026-11-13-ci-static-checks-zero-follow-up-N7H3.md`](2026-11-13-ci-static-checks-zero-follow-up-N7H3.md).

## Disposition

Vitest passes all existing coverage thresholds. Minitest passes the full suite and all remaining
public/protected misses retain explicit current reachability dispositions. The SimpleCov aggregate
still falls below all three configured minima, and the application preference-audit writer remains
absent. No coverage setting or behavior was weakened to change those results. The coverage
specification remains `implementing`.

## Current-tree integrity checks

After adding this record and updating the coverage spec, the unconfigured default-rule Gitleaks scan
still reports **118** findings in the current snapshot; no matched value was printed. The remaining
findings and disposition are recorded in
[`2026-11-13-ci-static-checks-zero-follow-up-N7H3.md`](2026-11-13-ci-static-checks-zero-follow-up-N7H3.md).
The snapshot included the updated spec and this evidence record.

`scripts/check-repository-knowledge` passed for the current spec and ordered-work-order/coverage
evidence set: **8 Skills/adapters, 67 documents, 6 evidence records**. `git diff --check` passed.
Credential paths have no changed files; `.github/workflows/ci.yml` remains pre-existing dirty
worktree content and was not edited. No commit or push was made.
