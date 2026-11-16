# Minitest Public/Protected Coverage — Current Resumption

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree already contained **1,102 changed or untracked paths** before this evidence
update, including extensive uncommitted work from earlier tasks. Results describe that combined
worktree. No commit or push was made. No CI file, credentials or database schema source was changed
in this coverage slice.

## Changes and focused tests

- Added coverage for `OperatorTelephonePublicIdBackfillOperation.call`, `RpPrincipal#policy_class`,
  the six generated Core bridge predicates, and `JitSecurityTurnstileConfig.stealth_site_key`.
- Added a public API absence assertion for the standalone JWK normalizer. It failed first with **1
  run / 1 assertion / 1 failure** while the method remained exposed. After removing the unused
  `JitSecurityJwtJwksService.normalized_public_jwk` wrapper and its unused requires, the focused JWT
  selection passed **38 runs / 254 assertions / 0 failures / 0 errors / 0 skips**.
- Removed `Umaxica::Valkey::Settings#[]` and `Umaxica::Valkey::ResponsibilityUrls.require_url` after
  repository caller searches found no code consumer. The current Settings loader already resolves
  the supported responsibilities. The Valkey topology ADR now records the old URL resolver as
  superseded. Existing Valkey settings/resolver/infrastructure tests passed **17 runs / 86
  assertions / 0 failures / 0 errors / 0 skips**.
- The other focused results were: backfill **6 / 16**, RP policy lookup **1 / 3**, Core bridge
  predicate contract **1 / 12**, and Turnstile site-key accessor **1 / 1**; all had zero failures,
  errors and skips. Those additions exercise existing contracts and required no behavior change.

Targeted RuboCop passed for nine related Ruby files with no offenses. `git diff --check` passed. The
focused tests and full run used the current explicit test writer list; `test_queue_db` appears in
that repository safety list but no Queue task or schema was changed.

## Full Rails verification

Command:

```text
env RUBYOPT=-W0 RAILS_ENV=test COVERAGE=true POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test
```

Minitest passed **7,516 runs / 50,260 assertions / 0 failures / 0 errors / 0 skips**. Nine
`AccessOpDataUnavailableError` worker-thread reports appeared in the concurrency tests for
administrative access locks and enforcement reconciliation; Minitest recorded no test errors. The
process exited **2** only after SimpleCov reported its unchanged thresholds below minimum:

| Metric   |                  Current | Minimum |
| -------- | -----------------------: | ------: |
| Lines    | 90.51% (30,120 / 33,275) |     98% |
| Branches |   62.24% (3,511 / 5,641) |     93% |
| Methods  |   85.89% (4,348 / 5,062) |     97% |

Output is retained at `/tmp/umaxica-coverage-resumption-2026-11-13.log`, outside the repository. No
threshold, exclusion, source ignore annotation, or checker configuration was changed. The latest
read-only checker command, `env RUBYOPT=-W0 RAILS_ENV=test bundle exec database_consistency`, exited
1 with the one previously characterized warning:

```text
UniqueIndexChecker fail OperatorChronicle uniq_operator_chronicles_sign_flow_halted index is unique in the database but does not have a uniqueness validator
```

The installed checker does not match this custom JSON-expression partial unique-index contract. No
warning was suppressed. The separate remaining **79 NOT VALID FK** validation plan remains
unimplemented pending its scoped approval.

## Public/protected method inventory

The current Rails runtime inventory joined with all 17 parallel SimpleCov resultsets contains
**2,571 rows**:

| Visibility         |      Rows |   Reached |  Missed | No SimpleCov location | Same-line mismatch |
| ------------------ | --------: | --------: | ------: | --------------------: | -----------------: |
| Public instance    |     1,602 |     1,349 |      99 |                   135 |                 19 |
| Public class       |       908 |       902 |       4 |                     0 |                  2 |
| Protected instance |        61 |        49 |      12 |                     0 |                  0 |
| **Total**          | **2,571** | **2,300** | **115** |               **135** |             **21** |

Compared with the previous OIDC-retirement inventory, nine current rows are now reached:
`RpPrincipal#policy_class`, six Core bridge generated predicates,
`OperatorTelephonePublicIdBackfillOperation.call`, and
`JitSecurityTurnstileConfig.stealth_site_key`. Three uncalled entrypoints were removed:
`JitSecurityJwtJwksService.normalized_public_jwk`, `Umaxica::Valkey::Settings#[]`, and
`Umaxica::Valkey::ResponsibilityUrls.require_url`. No new exact miss appeared.

All 115 exact misses have current caller dispositions:

- **103 controller or controller-concern methods** have bodies behind the missing Access owner-data
  API or removed OP data. The corresponding request paths have explicit unavailable/fail-closed
  tests; no fabricated empty success result or synthetic authorization bypass was added.
- **2 IAM mutation operations** are reached only after the same unavailable owner boundary; current
  request tests assert no grant mutation or success audit.
- **7 `ApplicationPolicy` protected role helpers** have no current application caller. The accepted
  Operator Capability ADR retains them, so they were neither removed nor invoked directly.
- `ArchitectureBaseline.write` is an explicit maintenance task that writes the tracked debt
  inventory; `Umaxica::TestEnvironment::DatabaseSafety.report` has no current caller and belongs to
  test-database configuration reporting; `Umaxica::Valkey::Settings#performance` is a configuration-
  only diagnostic getter. These paths were not forced through Minitest.

The **135 no-location** rows are generated readers/writers or other accessors without a one-to-one
SimpleCov method entry. The **21 same-line mismatches** are generated aliases/accessor writers
attributed to another runtime name. Neither category is counted as reached. Row-level temporary data
is under ignored `tmp/coverage-task/` files.

## Restore disposable test database state

The full fixture run toggled migration-owned constraint flags in APP Setting, ORG Setting and
Occurrence, a PostgreSQL fixture behavior documented in
[`evidence/2026-11-13-database-consistency-post-test-rebuild-F7K2.md`](2026-11-13-database-consistency-post-test-rebuild-F7K2.md).
Before each drop, a read-only catalog check confirmed the exact test database and zero active
sessions. Only these three test writers were individually dropped, created and migrated with their
Rails connection-specific tasks. The full `POSTGRESQL_TEST_PREPARE_DATABASES` list was supplied to
the repository guard; the Queue connection in that list was not operated on.

| Test DB               | Migration receipts | Unvalidated FKs after rebuild | Unvalidated CHECKs |
| --------------------- | -----------------: | ----------------------------: | -----------------: |
| `test_app_setting_db` |            17 / 17 |                             5 |                  0 |
| `test_org_setting_db` |            17 / 17 |                             9 |                  0 |
| `test_occurrence_db`  |          118 / 118 |                            63 |                  0 |

All nine scoped `db:drop:<writer>`, `db:create:<writer>`, and `db:migrate:<writer>` commands
exited 0. No tests ran after restoration because fixture loading would toggle the flags again. This
test- database rebuild confirms migration receipt counts and the `NOT VALID` catalog state only; it
does not establish production/shared row validity or migration load safety.

No JavaScript/TypeScript changed. The previously verified Vitest result remains **59 files / 588
tests at 100% statements, branches, functions and lines**; the command was not rerun in this slice.

## Remaining acceptance

- The full Minitest behavior suite passes, but all three existing SimpleCov thresholds remain below
  minimum.
- The 115 exact public/protected misses are classified; the 103 missing-owner action bodies remain
  explicitly blocked and are not reported as covered. Generated/mapping rows are likewise not
  counted as reached.
- The preference-change audit API still has no application writer. The partial-expression unique
  index remains a confirmed checker capability gap, and the separate 79-FK validation work awaits
  approval.
- The coverage specification remains `implementing`. No commit, push, CI change, or production/
  shared database operation occurred.
