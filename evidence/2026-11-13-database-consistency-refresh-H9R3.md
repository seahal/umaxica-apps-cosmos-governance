# Governance database consistency revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Branch: `feature`

At the start of this continuation, `git status --short` listed 1,090 paths. The worktree already
contained extensive uncommitted work and affected all observations. No commit or push was made.
Production/shared databases were not targeted. No migration source or CI file was changed in this
revalidation. `db/chronicle_structure.sql` was regenerated from a fresh logged test database using
the Rails dump task; the existing uncommitted Chronicle contract changes were retained.

## Scoped test database reconstruction

`Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!` confirmed that the exact targets below
were writable test databases. A PostgreSQL catalog check found zero connected sessions to them
before each drop. They were individually dropped, recreated and migrated using scoped Rails tasks;
no `drop:all` task was used.

An initial trace run stopped before any database mutation because the inherited shell value for
`POSTGRESQL_TEST_PREPARE_DATABASES` still named retired connections. `DatabaseSafety` rejected it.
The successful test runs supplied the current writer list from `config/ci.rb` explicitly.

| Test database         | Migration receipts after reconstruction | Immediately after migration            |
| --------------------- | --------------------------------------: | -------------------------------------- |
| `test_app_setting_db` |                                 17 / 17 | 5 unvalidated FK, 0 unvalidated CHECK  |
| `test_org_setting_db` |                                 17 / 17 | 9 unvalidated FK, 0 unvalidated CHECK  |
| `test_occurrence_db`  |                               118 / 118 | 63 unvalidated FK, 0 unvalidated CHECK |

For each target, the commands were `RAILS_ENV=test bin/rails db:drop:<writer>`, `db:create:<writer>`
and `db:migrate:<writer>`. A dump comparison immediately after the scoped rebuild matched all three
checked-in SQL dumps. The task did not change any app, org, occurrence, Queue, production or shared
schema source.

## Fixture behavior and focused reproduction

After the prior clean reconstruction, the full Rails suite initially reported one fixture-dependent
translation error in `RetentionPurgeJobTest`. The test created a `VisitorOccurrence` without
initializing its reference status. The test now calls `VisitorOccurrenceStatus.ensure_defaults!`
before creating that row. The focused test file then passed **13 tests / 50 assertions**; RuboCop
for that test file had zero offenses at the preceding checkpoint.

The full suite passed **7,506 tests / 50,238 assertions / 0 failures / 0 errors / 0 skips** after
this setup correction. A subsequent full run with SQL tracing also passed **7,506 tests / 50,226
assertions / 0 failures / 0 errors / 0 skips**. Its configured `db:test:prepare` scope included
`test_queue_db`, which remains up to date at five recorded migrations; no Queue schema source or
database was dropped or edited.

A second controlled reconstruction of only the three named databases reproduced the transition.
Before fixture loading, the catalog again showed **5 / 9 / 63** unvalidated FKs. The focused
`bin/rails test test/jobs/retention_purge_job_test.rb` run passed **13 / 50**. Rails SQL tracing
recorded fixture loading toggling **28**, **28**, and **73** FKs, respectively, through
`NOT ENFORCED` and back to `ENFORCED`; afterward the three catalogs showed **0** unvalidated FKs and
**0** unvalidated CHECK constraints. No validation migration ran. The pinned Rails adapter's
`insert_fixtures_set` wraps fixture insertion in `disable_referential_integrity`; the PostgreSQL
18.4+ path toggles enforcement. `verify_foreign_keys_for_fixtures = false` skips only the separate
post-insert check, so it does not preserve the schema-dump validation state. The test environment
comment and active spec now record this limitation. PostgreSQL's
[ALTER TABLE documentation](https://www.postgresql.org/docs/18/sql-altertable.html) distinguishes
adding a `NOT VALID` constraint from the explicit `VALIDATE CONSTRAINT` operation.

The original one-error full run and the corrected green run are retained in `/tmp` logs for this
session. Test data was disposable; no fixture data is retained as an application change.

## Final checks and remaining findings

- `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency` — exit **1**. One KEEP finding:
  `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`; the current 3.1.2 checker's
  attribute/index matching does not recognize the custom JSON-text validator and partial expression
  index. No checker configuration, exclusion, disablement or schema weakening was added.
- Before the final reconstructions, post-fixture `db:verify_no_schema_drift` exited **1**, listing
  APP Setting, Chronicle, Occurrence and ORG Setting. The three preference/occurrence stores diverge
  after fixture loading toggles their constraints. Chronicle previously had eight equivalent
  PostgreSQL 18 CHECK expression render differences.
- The migration-owned dumps retain **79** unvalidated FKs across five KEEP writers: APP Setting 5,
  ORG Setting 9, APP Signal 1, ORG Signal 1 and Occurrence 63. The previous approval covered a
  different 42-constraint set. The remaining 79 validation proposal stays unimplemented and
  unapplied pending its separate scope/recovery approval. The test fixture transition does not
  authorize that migration.
- The default test preparation also lists `test_queue_db` in its configured migration scope. Its
  five migration receipts are all up, and no Queue schema or migration file was changed.
- No production/shared row validity, database load, migration safety or post-deployment state was
  measured. No SQL dump was copied from post-fixture databases.
- After all full-suite runs, the three preference/occurrence test databases were individually
  dropped, recreated and migrated once more, after verifying exact targets and zero connected
  sessions. Their final catalog state is **5 / 9 / 63** unvalidated FKs and **0** unvalidated
  CHECKs.
- `test_chronicle_db` was separately verified with zero connected sessions, then dropped, recreated
  and migrated with `PostgreSQLAdapter.create_unlogged_tables = false` for that one migration
  process. It produced **34 / 34** migration receipts, zero unlogged tables/sequences, and zero
  unvalidated constraints. `RAILS_ENV=test bin/rails db:schema:dump:chronicle` regenerated the dump
  from that fresh logged schema, retaining the approved 19 FK validations and the sign-flow identity
  CHECK.
- Per-database `SchemaDriftVerification.dump_matches?` now reports **16 / 16** configured test
  schema dumps matching their databases. The standard `db:verify_no_schema_drift` command still
  exits **1** and lists only `db/chronicle_structure.sql` because it also rejects any changed
  tracked schema file in `git diff`; the generated file is intentionally uncommitted because no
  commit was requested. This is a worktree review gate, not a database/dump mismatch. Rerunning full
  tests is known to restore the three fixture-induced catalog differences.
- `git diff --check` and repository knowledge checks passed after this evidence update.

The Governance database specification remains `implementing`: one real checker capability gap, the
separate 79-FK approval and fixture-induced test catalog changes remain open. Chronicle's generated
dump now matches its migration-built database; the standard command reports the uncommitted dump
file because no commit was requested. No commit or push was made.
