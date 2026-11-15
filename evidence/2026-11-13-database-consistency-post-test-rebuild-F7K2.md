# Database Consistency Checker and Test Catalog Revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had **1,094 changed or untracked paths** before this evidence update. It already
contained extensive uncommitted changes. No commit or push was made. No production, shared, or Solid
Queue database was targeted. No application migration, schema source, credential, checker
configuration, or CI file was changed in this slice.

## Checker capability finding

The standard command `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency` exited **1**
with one finding:

```text
UniqueIndexChecker fail OperatorChronicle uniq_operator_chronicles_sign_flow_halted index is unique in the database but does not have a uniqueness validator
```

The locked gem is `database_consistency` **3.1.2**. Its `UniqueIndexChecker` filters for validator
`kind == :uniqueness` and then compares ordinary validator attributes/scope with parsed index
columns. Current upstream source uses the same algorithm; it does not match this custom expression
contract. See the upstream
[`UniqueIndexChecker`](https://raw.githubusercontent.com/djezzzl/database_consistency/master/lib/database_consistency/checkers/index_checkers/unique_index_checker.rb)
and
[`MissingUniqueIndexChecker`](https://raw.githubusercontent.com/djezzzl/database_consistency/master/lib/database_consistency/checkers/validator_checkers/missing_unique_index_checker.rb).

A read-only Rails catalog inspection found `JsonbTextUniquenessValidator` on `context`, with keys
`transaction_public_id` and `halt_generation`, and a matching partial PostgreSQL unique index on
those two JSON text expressions where `event_id = 18`. The installed checker's column parser returns
both exact expressions, but its standard validator matching cannot associate them with the custom
validator.

A temporary focused Minitest reproduced this capability gap. The first invocation stopped before
tests because it supplied only `test_chronicle_db` while the repository test safety guard requires
the complete verified test-writer list. Rerunning against that full verified catalog reached the
checker and produced **1 run / 3 assertions / 1 failure / 0 errors / 0 skips**: the existing exact
index returned `UniqueIndexChecker :fail`, where the contract assertion expected `:ok`. The
diagnostic test file was removed after recording the result; no checker was disabled, no
`.database_consistency.yml` was added, and no schema/model rule was weakened.

The KEEP finding remains a confirmed unsupported checker shape, not an unexplained model/index
mismatch. The existing PostgreSQL-backed model uniqueness tests and migration-owned expression index
remain intact.

## Restore migration-owned test database state

The full Rails coverage run completed before this reconstruction with **7,506 tests / 50,227
assertions / 0 failures / 0 errors / 0 skips**. Its fixture loading had changed the three test
catalogs for APP Setting, ORG Setting and Occurrence from the migration-owned `NOT VALID` state to
validated constraints. A read-only check confirmed all three exact targets were present in the
verified `RAILS_ENV=test` catalog and had **zero other connected sessions**. Only these isolated
test databases were dropped, recreated and migrated with their individual Rails tasks:

| Test database         | Migrations applied | Unvalidated FKs | Unvalidated CHECKs |
| --------------------- | -----------------: | --------------: | -----------------: |
| `test_app_setting_db` |            17 / 17 |               5 |                  0 |
| `test_org_setting_db` |            17 / 17 |               9 |                  0 |
| `test_occurrence_db`  |          118 / 118 |              63 |                  0 |

Each targeted `db:drop:<writer>`, `db:create:<writer>`, and `db:migrate:<writer>` command exited 0.
The safety variable contained the full verified writer list because the repository guard requires
it; the Queue entry was not operated on. A read-only query after migration confirmed the exact
database names, migration receipt counts and unvalidated constraint counts above.

After reconstruction, `env -u COVERAGE RAILS_ENV=test bin/rails db:verify_no_schema_drift` exited 1
and listed only the existing, uncommitted `db/chronicle_structure.sql`. APP Setting, ORG Setting and
Occurrence no longer appeared. The standard DatabaseConsistency command still reports the one
checker finding above. No tests were run after the final reconstruction, so the test databases
remain in migration-built state.

## Remaining scope

The migration-owned SQL dumps retain **79 NOT VALID FKs** across five KEEP writers: APP Setting 5,
ORG Setting 9, APP Signal 1, ORG Signal 1, and Occurrence 63. Their validation plan remains
unapplied; the earlier owner approval covered a different 42-constraint set. The separate 79-FK
validation and its monotonic rollback/recovery policy remain pending a scoped decision. No
production/shared data validity, validation lock duration, or migration load was measured.

No production/shared/Queue database, retained data, schema dump, or migration source was modified.
The test DB rebuild was limited to the three explicitly verified disposable test targets above.
