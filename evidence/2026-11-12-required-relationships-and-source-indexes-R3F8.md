# Required relationships and transfer-source indexes

Revision: 43db4906742db2fb13b238c9ccde378e4e1583b4

Extensive existing uncommitted split work and the task changes affected these results. The owner
approved all three required references, their RESTRICT foreign keys, explicit child-first cleanup,
and the four transfer-source indexes. Execution affected only independently created disposable
PostgreSQL databases and the two configured test Zenith databases; production was not executed.

## Changes

- `client_profiles.user_id`, `members.user_id` and
  `operator_workspace_accounts.department_id` become NOT NULL without a backfill.
- Existing names `fk_client_profiles_on_user_id`, `fk_rails_2e88fb7ce9` and
  `fk_operator_workspace_accounts_on_department_id` now use validated ON DELETE RESTRICT.
- Client profile/member and both Department account aliases refuse deletion while referenced.
  Child rows survive until explicit cleanup; no new automatic child destruction was introduced.
- Nonunique concurrent indexes cover source Client/Operator references in the four concrete
  ownership-transfer request tables. Existing resource/destination indexes remain intact.
- The required-attribute contract test no longer exempts these three columns.

Four Rails-generated migrations are in the App/Org principal history paths owned by Zenith:
`20261112122400`, `20261112122404`, `20261112122407`, `20261112122411`.
The requiredness/FK replacements commit atomically; validated foreign keys are completed after the
lock transaction. The nullability scan uses an explicit safety_assured block for the approved local
scope. Production scan/lock behavior was not verified or authorized by these results.

## TDD and regression

- Standalone metadata Red: all four source columns lacked a covering nonpartial leading index.
- Corrected behavior Red: 9 tests, 26 assertions, six failures and no errors. Three direct NULL
  writes succeeded and three parent deletes unexpectedly detached or permitted live children.
- Green: `PARALLEL_WORKERS=1 bin/rails test` over the focused relationship tests, ClientProfile,
  Member, Member public-ID uniqueness, OperatorWorkspaceAccount, Department, Client,
  IdentityDeadHistoryErasure and RequiredAttributeNotNullContract suites: **703 tests,
  2,845 assertions, zero failures, errors or skips**.
- RuboCop: all ten changed migration/model/test files passed. No coverage percentage is claimed
  for this unit. Schema dumps and global drift verification remain the root task's final step.

The initial test draft omitted Member's required explicit public ID and accessed an untranslated
Department error string. Setup was corrected and the field check uses structured error kinds;
no established assertion was weakened. Root added missing labels to the existing locale bundles.

## Independent PostgreSQL reconstruction and reversal

The driver used Rails DatabaseTasks and MigrationContext with unique receipt-owned databases:

| Database | Baseline migration count | Data tables hashed | Rows preserved |
| --- | ---: | ---: | ---: |
| `test_dbc_20261112_transfer_index_app` | 441 | 128 | 94 |
| `test_dbc_20261112_transfer_index_org` | 304 | 110 | 77 |

- All three existing-NULL probes caused NotNullViolation and preserved the original row hashes,
  nullability, FK definitions and migration history. Only the deliberately changed disposable
  fixture field was restored to its known original parent before the next probe.
- Both index migrations passed up/down/up with all table-row hashes and preexisting index
  definitions preserved. Only the four intended indexes changed; all are nonunique, ready and valid.
- EXPLAIN with sequential scans disabled demonstrated each source lookup could use its new index.
  This proves available access paths, not measured production performance.
- Both requiredness migrations passed up/down/up, preserving all row hashes and indexes. Down
  restored the exact original nullable columns and validated SET NULL FK definitions.
- Scoped application of the four versions to `test_app_zenith_db` and `test_org_zenith_db` confirmed
  zero preexisting NULLs and unchanged hashes for every data table.

Driver corrections were necessary before rehearsal: Rails required an actual prior migration
version rather than an arithmetic timestamp boundary; SecurityMode reference rows are migration-owned
and do not implement ensure_defaults!. The receipt-owned App target was resumed only after checking
its exact applied baseline versions. Unknown preexisting databases were never reused or dropped.

Temporary reproduction drivers and receipts: `tmp/rehearse_required_relationships.rb`,
`tmp/apply_required_relationship_test.rb`, `tmp/required-relationship-rehearsal/results.json` and
`tmp/required-relationship-rehearsal/official-test-apply.json`. They contain identifiers, definitions
and aggregate results, not a production data dump. No CI, test-helper or Solid Queue code changed.
