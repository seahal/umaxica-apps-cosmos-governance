# RP step-up history and uniqueness

Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`. Extensive pre-existing uncommitted work and
concurrent authorized remediation affected these results. This is not a clean-HEAD run.

## Scope and implementation

Base APP and Base ORG only. State public references/digests, transition owner/target pairs, attempt
ordinals and delivered-attempt slots now have matching model uniqueness validation. Outbox event UUIDs
and the rejected-only realm/client/context/reason tuple have create-time validation; their source
fields remain readonly. Delivery-state updates make no source-outbox uniqueness SELECT, verified with
the framework query assertion. Source writers and their lock order were preserved.

Two generated migrations change four physical FKs from CASCADE to RESTRICT and remove exactly four
redundant indexes. Each migration atomically replaces its two FKs with validation disabled, releases
DDL locks, then validates them. Index removal is concurrent. Down restores original indexes
concurrently and restores validated CASCADE FKs. No records, source lifetimes or physical purge
workflow were added or removed. The schema change was explicitly approved before implementation.

- APP migration `20261112120027`, SHA-256
  `cf47e720779bd2cd7728fd1a854b6f8b9d4e504b2bbf1a9ae8d262aaa0005a33`.
- ORG migration `20261112120054`, SHA-256
  `ccc8cc26fd344bb4d430e70f67602b8899c698d4a4bbb462f18239e92d08a9e1`.
- Both databases retain named `idx_rp_step_up_audit_outboxes_delivery` and
  `idx_rp_step_up_audit_attempts_number`, plus all other uniqueness/predicate definitions.

## TDD and regression

- State/transition/attempt Red: six model test files, seed 36517, 14 runs, 40 assertions,
  6 failures, 0 errors/skips. Duplicate candidates passed validation.
- Outbox Red: two model test files, seed 44247, 8 runs, 30 assertions, 4 failures, 0 errors/skips.
- History-deletion Red: `bin/rails test test/models/rp_step_up_history_retention_test.rb`,
  seed 10840, 4 runs, 12 assertions, 4 failures, 0 errors/skips. Model destroy refused, while
  direct `delete_all` silently cascaded and lost transition/attempt rows.
- Outbox Green plus delivery/start/restart regression: seed 13667, 20 runs, 176 assertions,
  0 failures/errors/skips.
- Final combined command:

  ```bash
  bin/rails test test/models/rp_step_up_state_test.rb test/models/rp_base_org_step_up_state_test.rb test/models/rp_step_up_state_transition_test.rb test/models/rp_base_org_step_up_state_transition_test.rb test/models/rp_step_up_audit_outbox_attempt_test.rb test/models/rp_base_org_step_up_audit_outbox_attempt_test.rb test/models/rp_step_up_audit_outbox_test.rb test/models/rp_base_org_step_up_audit_outbox_test.rb test/models/rp_step_up_history_retention_test.rb test/integration/base_step_up_start_test.rb test/operations/step_up_finalization_restart_race_test.rb test/jobs/step_up_audit_delivery_job_test.rb
  ```

  PostgreSQL 18.6, seed 38952: **38 runs, 308 assertions, 0 failures, 0 errors, 0 skips**.
  Includes direct PostgreSQL uniqueness checks naming the exact unique constraints; raw deletion
  refusal verifies `PG::RestrictViolation`, SQLSTATE `23001`, exact FK and surviving history rows.
  Existing delivery concurrency, retry, Chronicle identity and retention checks remain effective.
- Six-model lint plus its tests and the integration assertion: 13 files, no offenses. Final outbox,
  migration and history-test lint: 7 files, no offenses. Scoped diff whitespace checks passed.
- An existing `assert_empty RpBaseOrgStepUpAuditOutbox` integration assertion used the removed
  Active Record class `empty?` API. It was corrected to `.all`, preserving the no-records assertion.

## Existing-schema migration rehearsal

Used receipt-owned `test_dbc_20261112_governance_rp_base_app` and
`test_dbc_20261112_governance_rp_base_org`, confirmed through the actual pool database identity and
`Umaxica::TestEnvironment::DatabaseSafety`. Added disposable diagnostic principal/session/state,
transition, pending outbox and failed attempt records before migration. SHA-256 snapshots of all
application table row values were equal before and after every up/down/up phase. Metadata checks
confirmed exact rollback FK/index definitions, final validated RESTRICT FKs, and only the approved
index removals.

| Database | Up seconds | Down seconds | Second up seconds |
| --- | ---: | ---: | ---: |
| rp_base_app | 0.0245 | 0.0119 | 0.0149 |
| rp_base_org | 0.0218 | 0.0145 | 0.0169 |

`EXPLAIN` with sequential scans disabled selected `idx_rp_step_up_audit_attempts_number` for
outbox/ordinal reads and `idx_rp_step_up_audit_outboxes_delivery` for pending reads in both databases.
This establishes retained index eligibility on tiny local data, not production performance.

Operational commands were `RAILS_ENV=test bin/rails runner tmp/rehearse_rp_history_migrations.rb`
and `RAILS_ENV=test bin/rails runner tmp/migrate_rp_history_test.rb`. The first runner's SHA-256 is
`ec503c2ac6d3a5e171073977d9b975bb82a75eca16ecce9eec366416934b3c9e`. Its summarized results remain in
`tmp/keep-reconstruction/rp-history-rehearsal.json`. The second applied only these exact versions
to `test_rp_base_app_db` and `test_rp_base_org_db`; all four FKs were validated afterward.

An initial rehearsal fixture used a 20-character public ID and was rejected before commit or
migration. Correcting that fixture to 21 characters produced the successful rehearsal above. An
initial post-migration test expected the wrong Rails wrapper for PostgreSQL RESTRICT; it now checks
the actual PG subtype, SQLSTATE and FK name. Initial destroy-refusal tests also exposed missing
translation labels, which the coordinating locale change supplies.

## Checker and remaining verification

`RAILS_ENV=test bundle exec database_consistency` with no configuration, captured in
`tmp/rp-history-database-consistency.txt`, exited **1** for remaining other-model findings. There
were **zero fail lines for `RpStepUp*` or `RpBaseOrgStepUp*`** after this slice. This is not an
all-KEEP-zero claim and does not suppress remaining findings.

Fresh complete reconstruction, final generated dumps, `db:verify_no_schema_drift`, aggregate checker
and coverage remain with the coordinating verification. No final dumps, CI, Solid Queue or
production databases were changed by this slice. Schema changes use normal forward migrations and
will not alter an already deployed database until those migrations are explicitly applied.

Production sizes, traffic and lock contention were not measured. Concurrent-index failure can leave
an incomplete migration; inspect the exact catalog before recovery rather than blindly rerunning or
using existence guards. Reverting intentionally restores the original cascading deletion behavior.
