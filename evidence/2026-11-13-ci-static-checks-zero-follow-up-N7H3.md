# CI Static Checks Zero — Test Fixture Follow-up

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had 1,081 changed or untracked paths before this evidence was added and 1,082
afterward. Results describe that combined tree. This follow-up changed only two test files and this
evidence record. It did not change application behavior, CI, Compose configuration, credentials,
checker configuration, database schema, or Git history. No commit, push, or deployment was made.

## Safe Gitleaks finding reduction

The prior current-snapshot scan in
[`2026-11-13-ci-static-checks-zero-Q8V2.md`](2026-11-13-ci-static-checks-zero-Q8V2.md) reported 128
findings. Ten were fixed static UUID v4 values used as Avatar transfer idempotency fixtures. The
tests already require UUID v4 syntax; replacing those literals with `SecureRandom.uuid` preserves
the format and the tested reservation/replay behavior. In the expiration scenario, the two
operations continue to use distinct UUIDs. No assertion was removed or weakened.

The final snapshot was built from tracked and non-ignored working-tree files, omitting tracked paths
deleted from the current tree. An initial packaging attempt reported missing files for those deleted
paths; the snapshot was rebuilt using only existing worktree paths before the scan. The rebuilt
snapshot contained 8,123 files. After writing this evidence record, it was added to the snapshot for
a final current-tree scan of 8,124 files. Gitleaks used its default rules, no allow-list, and
redacted output:

```text
gitleaks detect --no-git --source tmp/ci-static-worktree-snapshot-final \
  --config tmp/ci-static-default-gitleaks.toml --redact --report-format json \
  --report-path tmp/ci-static-gitleaks-final.json
```

The count decreased **128 → 118** and stayed at 118 on the final snapshot including this record. No
matched value was printed or copied into this record.

| Remaining path group                                 | Findings | Classification                                                                           |
| ---------------------------------------------------- | -------: | ---------------------------------------------------------------------------------------- |
| `.github/workflows/ci.yml`                           |        2 | Valkey container image references in the already-dirty workflow; not changed here.       |
| `compose.yaml`                                       |        1 | Container image reference; no Compose behavior was changed.                              |
| Historical `evidence/` files                         |        6 | Preserved historical records.                                                            |
| Archived handoff work log                            |        2 | Preserved archived work log.                                                             |
| `research/2026-10-22-test-value-audit/duplicates.md` |      107 | Existing body-token digests from the data audit; not credentials confirmed by this scan. |

The workflow/Compose references are required image declarations. Rewriting them or weakening the
pinned image version would change runtime configuration to accommodate a generic-key false positive.
The audit digests and historical reports are retained evidence. They were not rewritten or deleted
without owner classification. No Gitleaks allow-list, ignore, inline suppression, or checker change
was added.

## Verification

| Command                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Result                                                                                                                                                                                                              |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `env -u COVERAGE RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test test/models/avatar_transfer_reservation_test.rb test/models/avatar_transfer_source_retention_test.rb` | Passed: **26 tests / 111 assertions / 0 failures / 0 errors / 0 skips**. PostgreSQL reported version 18.6.                                                                                                          |
| `env -u COVERAGE RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test`                                                                                          | Passed: **7,500 tests / 50,185 assertions / 0 failures / 0 errors / 0 skips**. Several concurrency tests printed `AccessOpDataUnavailableError` worker-thread reports, but Minitest recorded no failures or errors. |
| `bin/rubocop test/models/avatar_transfer_reservation_test.rb test/models/avatar_transfer_source_retention_test.rb`                                                                                                                                                                                                                                                                                                                                                                           | Passed: 2 files, 0 offenses.                                                                                                                                                                                        |
| `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency`                                                                                                                                                                                                                                                                                                                                                                                                                            | Exit 1 after `No configuration files were provided`; the sole finding is `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`. No checker configuration exists.                                            |
| `scripts/check-repository-knowledge` for this record, the coverage revalidation record, the updated coverage spec, and the ordered work-order evidence set                                                                                                                                                                                                                                                                                                                                   | Passed: 8 Skills/adapters, 67 documents, 5 evidence records.                                                                                                                                                        |
| `git diff --check`                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Passed.                                                                                                                                                                                                             |
| Credential path status                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | No changed paths. `.github/workflows/ci.yml` remains dirty from earlier work and was not edited.                                                                                                                    |

The test command prepares only the configured local test writer databases. No production, shared, or
external database was prepared or modified.

## Work-order disposition

The fixture findings are removed without test weakening. The overall static-check zero acceptance
remains unmet: the current snapshot still has **118 Gitleaks findings**, and the released
DatabaseConsistency checker still has **one** valid JSON-expression/partial-unique-index report as
documented in Q8V2. All findings remain visible. Owner classification is still needed for the
historical audit material; no schema or model change was made because the remaining checker report
is a supported-shape limitation and its PostgreSQL invariant is covered by direct tests.
