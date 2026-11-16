# Governance database consistency

Status: implementing

Authority: owner request on 2026-11-12, subsequently narrowed to Governance only.

Improve surviving PostgreSQL contracts without checker exclusions or weaker business invariants.
Preserve existing uncommitted split work. CI and Solid Queue are excluded. Production and shared
data are outside destructive reconstruction authorization.

## Acceptance

- AC-1: Classify every configured database before implementation; unresolved ownership remains
  pending.
- AC-2: Demonstrate meaningful changes with failing tests followed by passing PostgreSQL tests,
  relevant regressions and lint. Keep database enforcement independent of model validation.
- AC-3: Run unconfigured DatabaseConsistency and separate KEEP findings from other classifications.
- AC-4: Verify reconstruction and schema agreement for changed KEEP databases using isolated data.

## Initial classification

Reading replicas follow their writer's classification; separate test replica databases do not imply
separate ownership.

| Classification | Connections                                                                  | Basis                                                                                                                                                                  |
| -------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| KEEP           | primary                                                                      | Current database configuration explicitly owns durable Flipper settings.                                                                                               |
| KEEP           | app_zenith, org_zenith                                                       | Latest access-governance ownership backlog assigns accounts, credentials, organizations and roles to Governance. OP-specific tables still need individual disposition. |
| KEEP           | avatar                                                                       | Accepted cosmos-base-surface-decomposition ADR assigns canonical avatar/social data to Governance.                                                                     |
| KEEP           | rp_base_app, rp_base_org, rp_tech_org                                        | The same decomposition decision assigns these RP surfaces to Governance.                                                                                               |
| TRANSFER       | op_base_app, op_base_org                                                     | Latest ownership decision assigns OP state to Access; do not change source schemas.                                                                                    |
| PENDING        | publishing                                                                   | Press route transfer does not itself decide physical schema disposition.                                                                                               |
| PENDING        | app_setting, org_setting, com_setting                                        | Preference ownership direction does not settle physical consolidation.                                                                                                 |
| PENDING        | app_signal, org_signal, chronicle, occurrence, search                        | Post-split physical persistence disposition remains unresolved.                                                                                                        |
| PENDING        | storage                                                                      | Explicitly reserved, not an active KEEP redesign target.                                                                                                               |
| PENDING        | rp_core_app, rp_core_org, rp_warp_app, rp_warp_org, rp_palm_app, rp_edit_org | Surface transfer alone does not settle physical database disposition.                                                                                                  |
| EXCLUDED       | queue                                                                        | Owner explicitly excludes Solid Queue.                                                                                                                                 |

Legacy principal migration directories belong to Zenith history, not separate configured databases.
Old publisher, principal, com_zenith and cache names are absent from current database configuration.
Solid Cache retirement does not authorize any Solid Queue change.

## Sequence and open verification

1. Capture the complete unconfigured checker baseline and map findings to owners.
2. Audit independent KEEP model groups, starting with concrete reproducible defects.
3. Define each contract and add tests before changing models or migrations.
4. Verify each unit, then reassess the complete KEEP scope.

Initial standard checker run exited 1 with findings. No zero-warning or reconstruction claim has
been established. Database access requires execution outside the restricted sandbox; primary
accepted connections there. Material acceptance remains open until recorded verification exists.

## 2026-11-12 approved schema units

- The owner approved replacing nullable passkey backup observations with two independent explicit
  string state axes; see [passkey metadata](passkey-backup-metadata.md).
- The owner approved validating all 42 existing unvalidated constraints found in migration-built
  KEEP databases: Avatar eight FKs, APP Zenith seventeen FKs and five CHECKs, ORG Zenith eleven FKs
  and one CHECK. Definitions and data remain intact. Invalid existing rows stop validation rather
  than being deleted. Rollback keeps validated constraints; production execution is not authorized.
- The owner approved RP Base APP/ORG source-history FK alignment: four CASCADE actions become
  RESTRICT, matching the existing Model refusal. Four redundant indexes are removed while the
  covering composite UNIQUE, partial UNIQUE and remaining delivery index stay intact. Recovery
  restores the original FK/index definitions; retained-row deletion is not part of this change.

Initial isolated reconstruction completed for all seven KEEP databases. After the 42-constraint
validation migrations, normalized schema dumps of current test databases and their independent
migration-built counterparts match for all seven. These observations precede later schema units;
final reconstruction and equality must be repeated for the finished worktree.

The fixed-ID completion-method catalog is application-owned. Durable ID-1 requires bigint even for
bounded catalogs; the initial inference that smallint was only a checker preference was incorrect.
The actual CHECK pins IDs to one through four, but does not supersede the accepted type contract.

Additional owner-approved units:

- Widen completion-method PK and referencing completion method FK from smallint to bigint,
  preserving the fixed IDs, rows and all constraints. Numeric down migration is bounded by the
  retained one-through-four CHECK and FK.
- Add five nonunique indexes for status/method reverse lookups and four additional nonunique
  source-actor indexes for ownership-transfer history. Existing partial/unique constraints stay.
- Require ClientProfile's Client, Member's Client and OperatorWorkspaceAccount's Department at the
  database boundary. The clarified owner decision makes all three FKs RESTRICT and Model parent
  relations restrict_with_error. This explicitly supersedes the initial mistaken description that
  Member-first automatic deletion was already the existing behavior: existing code used nullify. No
  automatic Member/Profile/Workspace deletion is introduced. Existing NULL data stops migration; no
  fabricated owner/backfill is authorized. Down restores original nullability and SET NULL FKs.

## Ownership amendment after non-Governance removal (2026-11-12)

The owner's explicit removal/retention inventory supersedes the initial pending classifications
above. Current KEEP writers are primary, storage (empty reservation), chronicle, app_zenith,
org_zenith, avatar, app_setting, org_setting, com_setting, app_signal, org_signal, occurrence,
rp_base_app, rp_base_org and rp_tech_org. Queue remains EXCLUDED. OP APP/ORG, Publishing, Search and
six foreign RP connections are retired from Governance configuration and code; their physical
storage was not dropped and no external transfer completion is claimed.

The removal phase independently rebuilt 15 retained schema-owning stores in disposable development
and test environments, retaining all existing schema sources. Its full-suite checkpoint has 7,647
tests, 50,778 assertions, 16 failures, zero errors/skips. Those failures comprise nine existing
original-task Red cases, five unrelated retained Preference/CSP contract disagreements, one role
placement assertion (subsequently corrected) and one removal fixture keyword mismatch (corrected).
The workflow inventory patch remains blocked by a read-only mount. Final verification remains open.

The expanded PostgreSQL metadata audit found 98 additional NOT VALID foreign keys in six now-
confirmed KEEP databases. The exact plan is prepared, not applied. Existing definitions, actions,
columns and data must remain unchanged; historical orphan rows stop validation without deletion.
Their monotonic rollback policy requires a scoped owner decision, independently of the earlier
42-constraint approval. No new schema unit is approved by this paragraph.

## Expression-index checker result

The final unconfigured `database_consistency` run exits 0 with no finding lines for the current
worktree. The prior `OperatorChronicle` expression-index finding is now represented by a real model
validator with PostgreSQL's matching JSON text semantics and recognized in both checker directions.
No checker exclusion or schema alteration was used. The generic checker fork patch and its 478 RSpec
examples are recorded in
[`evidence/2026-11-12-database-consistency-baseline-D8K2.md`](../../evidence/2026-11-12-database-consistency-baseline-D8K2.md).

This result does not resolve the separately documented duplicate-NULL gap in the historical audit
identity contract, and it does not validate the 98 additional NOT VALID foreign keys. The 98-FK
validation remains pending scoped approval. Therefore this specification remains `implementing`; the
zero-finding checker result alone does not close AC-2 or AC-4.

## Latest verification after coverage and removal continuation

The unconfigured KEEP checker was rerun against the current worktree and exited **0** with no
finding output. The latest coverage-disabled full Minitest suite passed **7,657 tests / 51,376
assertions / 0 failures / 0 errors / 0 skips**. SimpleCov separately ran the same tests but exited 2
at **86.08% line, 57.16% branch and 77.03% method coverage**, below its unchanged 98% / 93% / 97%
gates. The latest Vitest coverage run passed **68 files / 696 tests** and the unchanged 99% gates at
100% statements, 99.7% branches, 100% functions and 100% lines. These results are recorded in the
coverage checkpoint evidence. They do not validate the remaining 98 foreign keys or close the
Chronicle JSON identity gap; this specification remains `implementing`.

## Latest approved-scope reconstruction and verification

After the latest approved APP/ORG ownership, identifier-width, index and RP history migrations, new
isolated PostgreSQL databases were created for `app_zenith`, `avatar`, `org_zenith`, `primary`,
`rp_base_app` and `rp_base_org` in both development and test. Each environment replayed the current
migration history from empty databases: 894 migration receipts per environment. These names were
unique `development_gov_dbconsistency_resume_20261112_*` and
`test_gov_dbconsistency_resume_20261112_*` targets. The shared development databases and Solid Queue
were not used for this reconstruction. All twelve migration runs and schema dumps completed.

The fresh development and test schemas match each other for all six stores. Fresh schemas also match
the current working-tree SQL dumps for APP Zenith, Avatar, ORG Zenith, RP Base APP and RP Base ORG;
`primary` has no configured schema dump. A read-only catalog check found zero unvalidated foreign
keys and zero unvalidated CHECK constraints in each of the twelve fresh databases. This verifies the
approved 42-constraint validation slice in its relevant stores; it does not validate the separately
proposed 98 constraints in other KEEP stores.

A separate read-only dump comparison against the existing test database matched 11 retained
schema-owning stores and found four differences: APP Setting, ORG Setting, Occurrence and Chronicle.
Those differences remain consistent with the recorded 98-FK split: the existing test databases have
validated constraint states while the current dumps and independent fresh migrations retain
`NOT VALID`. No attempt was made to rewrite those four schemas or the 98-constraint plan. The
unconfigured `database_consistency` command exited **0**, printed only
`No configuration files were provided`, and reported zero KEEP findings. The remaining 98-FK
validation and the OperatorChronicle event-18 JSON identity contract remain open; the specification
stays `implementing`.

## Chronicle identity and final checker status (2026-11-13)

This is the latest checkpoint and supersedes the earlier checker and Chronicle-gap statements above.
The event-18 identity gap is implemented: both JSON text-extracted identity components must be
non-NULL. A stricter CHECK is added unvalidated, validated separately, and the weaker key- presence
CHECK is then removed. Model and direct PostgreSQL tests cover missing and JSON-null values, an
array carrying the key names, and the validation-bypass path. Existing identity extraction semantics
and the expression unique index remain intact. See
[`halt-audit-identity-gap.md`](halt-audit-identity-gap.md) for the contract disposition.

The same migrations validate Chronicle's 19 existing foreign keys without changing definitions or
data. On an empty, disposable test Chronicle database, all migrations completed, the normalized dump
matched the rebuilt database, and PostgreSQL reported zero unvalidated constraints. Existing invalid
audit rows or foreign-key references stop validation without automatic repair. Production and shared
databases were not accessed; their row validity and validation costs are not verified.

The published checker run against the current uncommitted worktree exits **1** with one KEEP finding
and no checker configuration: `UniqueIndexChecker` does not recognize the custom JSON-text
uniqueness validator paired with the partial expression index. The six earlier
`ColumnPresenceChecker` findings for `Bureau.name`, `Bureau.title`, `Agent.title`,
`Enterprise.name`, `Enterprise.title`, and `ClientPersona.title` are resolved.
`ProjectedAttributePresenceValidator` preserves the rule that a missing projected column is not a
NULL value while requiring the value whenever the attribute is loaded; complete writes remain
protected by PostgreSQL NOT NULL constraints. Existing PostgreSQL-backed model tests cover projected
saves, nil rejection and direct-insert rejection. No checker configuration or exclusion was added.
The remaining expression-index finding is not suppressed, so AC-3 and the zero-finding objective are
not met.

The full Rails suite passed 7,492 tests / 49,888 assertions / zero failures, errors or skips with
`PARALLEL_WORKERS=1` against prepared base test databases. Related PostgreSQL-backed model tests
passed 8 / 84; Chronicle delivery/policy tests passed 33 / 130; architecture and placement guards
passed 11 / 32. A coverage-enabled full run also passed all 7,492 tests, then exited 2 because
coverage was 90.27% line, 61.85% branch and 86.41% method against the repository thresholds of 98%,
93% and 97%. The changed projected-presence validator's lines, branches and methods were covered.

`db:verify_no_schema_drift` exits 1 and lists APP Setting, Chronicle, Occurrence and ORG Setting.
Normalized Chronicle dump comparison still differs in eight PostgreSQL 18 `pg_dump` CHECK expression
renderings; the table/index/foreign-key definitions otherwise match, and all 29 CHECKs and 30
foreign keys in the migration-built Chronicle test database are validated. APP Setting, Occurrence
and ORG Setting retain the earlier test-database versus dump differences associated with the 98
additional unvalidated constraints. That separate validation proposal remains pending its
scope/recovery decision and was not applied. The specification remains `implementing`.

## Post-follow-up revalidation (2026-11-13)

After the PS256, static-check, and unreachable-ceremony work orders, the current unconfigured
`RAILS_ENV=test bundle exec database_consistency` run still exits **1** with only the same
`OperatorChronicle.uniq_operator_chronicles_sign_flow_halted` finding. The model's
`jsonb_text_uniqueness` validator and PostgreSQL partial expression unique index remain the
application and database contract; no checker configuration, exclusion, or schema weakening was
added. Focused Chronicle identity/uniqueness tests passed **6 tests / 56 assertions**. The full
Rails suite after the ceremony cleanup passed **7,492 tests / 50,156 assertions**, as recorded in
its evidence.

`db:verify_no_schema_drift` still exits **1** for `app_setting`, `chronicle`, `occurrence`, and
`org_setting`. The Chronicle-specific PostgreSQL 18 dump-rendering differences and the other three
stores' outstanding 98-FK validation state are described above. Those 98 validations remain
unapproved and unapplied. No new schema reconstruction, migration, shared-database operation,
production operation, or CI edit occurred during this revalidation. Therefore zero
DatabaseConsistency findings and complete schema-dump agreement remain unmet, and this specification
remains `implementing`.

## Current database revalidation (2026-11-13)

The current unconfigured `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency` run exits
**1**. It prints only `No configuration files were provided` and one KEEP finding:
`OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`. The installed and current RubyGems
release is 3.1.2. Its `UniqueIndexChecker` only accepts validators whose `kind` is `:uniqueness` and
compares their validator attributes with parsed index columns. It does not recognize this model's
custom `jsonb_text_uniqueness` validator paired with PostgreSQL JSON-text expression columns. The
existing PostgreSQL-backed uniqueness tests and database index still enforce the same halt identity
tuple; changing that correct tuple or excluding the finding would weaken the contract. This is a
verified checker capability gap, not an unexamined warning. Sources:
[RubyGems 3.1.2](https://rubygems.org/gems/database_consistency) and the upstream
[UniqueIndexChecker](https://github.com/djezzzl/database_consistency/blob/master/lib/database_consistency/checkers/index_checkers/unique_index_checker.rb).

The current read-only test-catalog scan found no unvalidated FK or CHECK constraints in
`app_setting`, `org_setting`, `occurrence` or `chronicle`; `app_signal` and `org_signal` each have
one unvalidated FK. This is existing test-database state, not evidence about production/shared
databases. The migration-built contract and SQL dumps retain **79** unvalidated FKs in five KEEP
writers: APP Setting 5, ORG Setting 9, APP Signal 1, ORG Signal 1, and Occurrence 63. Chronicle's
separate migration `20261113133248_validate_chronicle_reference_foreign_keys.rb` already validated
its 19 FKs in a disposable test database. The corrected 79-FK proposal remains unimplemented and
unapplied pending its separate scope/recovery approval; the earlier 42-FK approval does not cover
it. See [remaining FK validation](remaining-foreign-key-validation.md).

`RAILS_ENV=test bin/rails db:verify_no_schema_drift` still exits **1** for APP Setting, Chronicle,
Occurrence and ORG Setting. A per-configuration read-only comparison distinguishes these causes:

- APP Setting, ORG Setting and Occurrence have migration dumps with respectively 5, 9 and 63
  `NOT VALID` FKs, while the current test databases have those FKs validated. Overwriting the dumps
  from these current databases would hide the fresh-migration contract difference.
- Chronicle has eight PostgreSQL 18 `pg_dump` renderings of equivalent CHECK expressions that differ
  from the checked-in dump's earlier rendering. Its schema dump is also an uncommitted worktree
  change, so the task correctly remains non-clean until that scoped change is committed.

No production/shared database, Solid Queue schema, or retained data was changed or inspected for
this revalidation. No checker configuration, validation migration for the remaining 79 FKs, schema
dump rewrite, or CI change was introduced. The 79-FK proposal, the single confirmed checker
capability gap, and four schema-dump comparison results keep this specification `implementing`.

## Fixture-induced FK validation in test databases (2026-11-13)

A controlled reconstruction confirmed why the three test-database dumps disagree after tests. The
exact disposable writers `test_app_setting_db`, `test_org_setting_db` and `test_occurrence_db` were
verified in the current test catalog with no connected sessions, then individually dropped,
recreated and migrated. Before fixture loading, PostgreSQL reported **5 / 9 / 63** unvalidated FKs
and zero unvalidated CHECK constraints; migration receipts were complete at **17 / 17, 17 / 17, and
118 / 118**. The focused `test/jobs/retention_purge_job_test.rb` run passed **13 tests / 50
assertions**. Its SQL trace showed fixture loading changing the constraints through `NOT ENFORCED`
and `ENFORCED`, and the read-only catalog scan afterward found zero unvalidated FKs in all three
databases. A full suite run after the test-fixture setup correction passed **7,506 tests / 50,238
assertions / 0 failures / 0 errors / 0 skips**.

The test configuration setting `verify_foreign_keys_for_fixtures = false` suppresses Rails' separate
post-insert check, but does not suppress `insert_fixtures_set`'s `disable_referential_integrity`
wrapper. On PostgreSQL 18.4+, Rails toggles fixture constraints through `NOT ENFORCED` / `ENFORCED`;
the latter validates them. This is why test execution changes the catalog without a new application
migration. The test configuration comment now states that limitation. Do not copy post-fixture
database state into the migration-owned dumps. Fixing this state transition requires a separate
test-fixture strategy or explicit approval for the relevant validation changes; no test-only catalog
edits or silent schema normalization were added.

After fixture loading, `database_consistency` still exits **1** with the single documented
`OperatorChronicle` JSON-expression uniqueness capability gap. `db:verify_no_schema_drift` exits
**1** with APP Setting, Chronicle, Occurrence and ORG Setting. The first, third and fourth are
explained by the fixture transition; Chronicle retains eight PostgreSQL 18 `pg_dump` CHECK
expression render differences. The remaining 79-FK validation proposal remains unimplemented and
unapplied pending its separate scope/recovery approval. Production/shared schemas, data validity,
and validation costs remain unverified.

After recording the post-fixture behavior, the three exact test writers were dropped, recreated and
migrated once more, with zero target sessions verified first. The final read-only catalog scan now
shows the migration state again: APP Setting 5, ORG Setting 9 and Occurrence 63 unvalidated FKs;
Chronicle 0; APP Signal and ORG Signal 1 each. The final `db:verify_no_schema_drift` run lists only
Chronicle. No test was run after this final reconstruction. The focused and full test results above
remain valid, and rerunning fixtures is known to restore the three comparison differences.

## Chronicle schema dump regenerated from fresh migrations (2026-11-13)

The Chronicle test database was then rebuilt separately after `DatabaseSafety` confirmed the exact
`test_chronicle_db` target had zero connected sessions. For this one migration process, the Rails
PostgreSQL adapter's test-only `create_unlogged_tables` class setting was set to false so the schema
dump would describe ordinary logged tables. PostgreSQL 18.6 replayed all **34 / 34** Chronicle
migrations; the resulting database had zero unlogged tables/sequences and zero unvalidated
constraints. `RAILS_ENV=test bin/rails db:schema:dump:chronicle` regenerated
`db/chronicle_structure.sql` from this migration-built logged schema, preserving the validated 19
Chronicle FKs and the sign-flow identity CHECK.

The versioned dump comparator now reports **16 / 16** configured test database dumps matching their
databases, including Chronicle. The overall `db:verify_no_schema_drift` task still exits **1** and
lists only `db/chronicle_structure.sql` because it also rejects changed tracked schema files in
`git diff`; this generated dump remains uncommitted under the no-commit instruction. The focused
`test/tooling/database_reconstruction_authority_test.rb` passed **5 tests / 45 assertions**. No full
suite was run after the final test database reconstructions. The remaining 79-FK proposal and the
single custom JSON expression uniqueness checker finding remain open.

## Checker capability recheck (2026-11-13)

The current standard `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency` run still
exits 1 with one finding: `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`. The locked
`database_consistency` 3.1.2 `UniqueIndexChecker` considers only validators whose `kind` is
`:uniqueness`, then compares validator attributes and scope against parsed index column names. The
model uses `JsonbTextUniquenessValidator` (`kind: :jsonb_text_uniqueness`, attribute `context`, keys
`transaction_public_id` and `halt_generation`) and a PostgreSQL unique expression index on those two
JSON text values where `event_id = 18`. The corresponding PostgreSQL-backed uniqueness and model
tests remain in place.

A focused checker contract test was added temporarily and run against the current PostgreSQL test
catalog. Its first attempt stopped before test execution because the test safety guard requires the
complete verified writer list. Rerunning with that list reached the checker and failed as expected:
the exact, existing partial expression index returned `UniqueIndexChecker :fail`. The diagnostic
test was removed after recording the result; no checker was disabled, no `.database_consistency.yml`
was created, and no valid schema or model contract was weakened. The locked checker source and
current upstream source both use the same validator-kind/column matching; see the upstream
[`UniqueIndexChecker`](https://raw.githubusercontent.com/djezzzl/database_consistency/master/lib/database_consistency/checkers/index_checkers/unique_index_checker.rb)
and
[`MissingUniqueIndexChecker`](https://raw.githubusercontent.com/djezzzl/database_consistency/master/lib/database_consistency/checkers/validator_checkers/missing_unique_index_checker.rb).
This remains a confirmed unsupported custom-expression shape, not an unresolved model/index
mismatch. KEEP checker findings remain **1**.

The separate **79 NOT VALID foreign keys** remain unapplied: APP Setting 5, ORG Setting 9, APP
Signal 1, ORG Signal 1, and Occurrence 63. Their validation migration and irreversible recovery
policy still require a separate scoped risk/recovery decision; the prior approval covered a
different 42 constraints. No production or shared DB operation was performed. The
database-consistency specification remains `implementing`.

## Test writer state restored after final coverage run (2026-11-13)

The last full Rails coverage run caused the known fixture transition in APP Setting, ORG Setting and
Occurrence test databases. Before reconstruction, a read-only catalog scan showed their FKs
validated; `db:verify_no_schema_drift` consequently listed those three dumps plus Chronicle. After
confirming the exact test targets were present in `DatabaseSafety`'s test catalog and had zero other
sessions, only `test_app_setting_db`, `test_org_setting_db`, and `test_occurrence_db` were
individually dropped, recreated and migrated. No Queue, shared or production database was targeted.

Fresh migration receipts and catalog state are **17 / 17 migrations, 5 unvalidated FKs, 0
unvalidated CHECKs** for APP Setting; **17 / 17, 9, 0** for ORG Setting; and **118 / 118, 63, 0**
for Occurrence. This restores the migration-owned state without validating constraints or changing
their definitions. No test ran after this final reconstruction. The full coverage run immediately
before it passed **7,506 / 50,227** with zero Minitest failures, errors or skips.

After reconstruction, `db:verify_no_schema_drift` exits **1** and lists only the already-uncommitted
`db/chronicle_structure.sql`; APP Setting, ORG Setting and Occurrence no longer appear. The standard
DatabaseConsistency command exits **1** with the same single confirmed JSON-expression uniqueness
checker gap. The **79** migration-owned unvalidated FKs remain unapplied pending the separate
scope/recovery decision. No test, schema source, migration source, checker configuration or CI file
was changed by this reconstruction. Evidence is in
[`2026-11-13-database-consistency-post-test-rebuild-F7K2.md`](../../evidence/2026-11-13-database-consistency-post-test-rebuild-F7K2.md).

## DatabaseConsistency finding closed (2026-11-14)

The only current finding, `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`, is closed
without changing the Chronicle schema. DatabaseConsistency 3.1.2's `UniqueIndexChecker` accepts
validators with `kind == :uniqueness`, then compares validator attributes and scope with parsed
index columns and compares `conditions` with the partial predicate. The partial-predicate check is
supported. The earlier mismatch was that `JsonbTextUniquenessValidator` exposed a custom kind and
the source JSONB attribute rather than metadata for the two expression terms.

`JsonbTextUniquenessValidator` now reports the exact normalized expression terms, scope and
`event_id = 18` condition while continuing to query the same `context ->>` values on the writing
role. PostgreSQL's existing partial unique index remains authoritative for concurrent inserts. The
existing model and direct-SQL tests still cover duplicate rejection and independent generations; the
checker command now exits zero. No migration, index change, constraint weakening, checker
configuration, exclusion or CI edit was made.

The `chronicle` database and retained audit history remain Governance-owned under the current
surface-local database boundaries. The event itself records an authentication-flow halt, and the
accepted Cosmos split assigns authentication facts and their audit writes to Access. A caller search
found no current Governance writer for `SIGN_FLOW_HALTED`; therefore new writes belong in Access
when that path is implemented. Governance's existing event reference, rows and index remain in place
until a separately scoped history-transfer or retention decision. This is an ownership inference
from the accepted split, not approval to delete historical records.

The full Rails test run after this change completed 7,596 tests / 50,855 assertions with 31
failures, zero errors and zero skips. The two focused OperatorChronicle uniqueness files passed 6
tests / 56 assertions. The full run's failures include the previously observed step-up and local RP
verification mismatches plus failures in CSRF, preference and other request tests; the dirty
worktree had an earlier coverage-enabled full run with 13 failures, but its complete failure-name
list was not retained. The six failures named in the focused diagnostics remain; the other current
failures are not classified as pre-existing or caused by this change. See
[`2026-11-14-database-consistency-zero-DCA4.md`](../../evidence/2026-11-14-database-consistency-zero-DCA4.md).
