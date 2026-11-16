# Database consistency remediation checkpoint

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Branch: `feature`

The worktree contained extensive pre-existing uncommitted changes. `git status --short` listed 992
entries before this evidence file was added; checks ran against the combined worktree. No reset,
stash, commit, push, production database or shared development database operation occurred. Only the
disposable `test_chronicle_db` was dropped and recreated, as authorized. No CI file was changed.

## Changes

- Added `ProjectedAttributePresenceValidator`, which keeps required-value validation for loaded
  attributes and skips only attributes omitted from a projected Active Record query. This retains
  partial-record update behavior while presenting an unconditional presence validator to the
  checker. PostgreSQL NOT NULL remains authoritative for complete writes.
- Added PostgreSQL-backed model tests for required `name` / `title` values on `Bureau`,
  `Enterprise`, `Agent` and `ClientPersona`: nil values fail model validation, direct `insert_all!`
  NULL writes fail at PostgreSQL, and updates from records without the other projected attribute
  preserve its stored value.
- Tightened the `SIGN_FLOW_HALTED` event identity contract: both
  `context ->> 'transaction_public_id'` and `context ->> 'halt_generation'` must be non-NULL. The
  model and CHECK reject missing/JSON-null extracted values, including when validations are
  bypassed. Existing non-NULL JSON text extraction and the partial expression unique index remain.
- Added separate migrations to add the strict CHECK as `NOT VALID`, validate it, remove the weaker
  key-presence CHECK, and validate the 19 existing Chronicle foreign keys. Invalid historical rows
  are not repaired or deleted; validation fails. Foreign-key rollback preserves the stronger
  validated state because PostgreSQL cannot unvalidate an FK without dropping it.
- Updated `db/chronicle_structure.sql` through Rails' schema dump and recorded the implemented
  identity contract in the active specification and its investigation note.

## TDD and verification

- **Red:** before the Chronicle CHECK/model change, the updated sign-flow test failed because
  JSON-null and array-key contexts were accepted. The unconfigured checker baseline reported seven
  findings: six projected-column findings plus the Chronicle JSON expression index.
- **Green:** focused model tests after the projected-presence validator change: 8 tests / 84
  assertions, no failures. Chronicle delivery/policy tests: 33 / 130. Architecture and object
  placement guards: 11 / 32. The original identity red case passed after the model and PostgreSQL
  CHECK changes; focused Chronicle tests had also passed 6 / 56 before the final validator refactor.
- **Full Rails suite:** `PARALLEL_WORKERS=1 bin/rails test` passed 7,492 tests / 49,888 assertions,
  0 failures, 0 errors, 0 skips. Single-worker mode used the prepared base test DBs and avoided
  stale worker clones after the test-only Chronicle rebuild.
- **Coverage:** `COVERAGE=true PARALLEL_WORKERS=1 bin/rails test` passed 7,492 tests / 49,892
  assertions with no test failures, but exited 2 because repository coverage thresholds were not
  met: 90.27% lines (minimum 98%), 61.85% branches (minimum 93%) and 86.41% methods (minimum 97%).
  The new projected-presence validator measured 10/10 executable lines, 4/4 branch arms and 3/3
  methods covered.
- **RuboCop:** 14 touched Ruby files, no offenses. `git diff --check` passed.
- **Clean test Chronicle rebuild:** `db:drop:chronicle`, `db:create:chronicle`, then the repository
  `db:test:prepare` migration workflow completed. The first `db:migrate:chronicle` attempt loaded
  the SQL structure snapshot, which records migration receipts but not data-migration rows; it was
  discarded and replaced with the repository's empty-database migration workflow. The rebuilt
  Chronicle database has 48 tables, 34 migration receipts through `20261113133248`, and the two
  owner-approved `compliance` / `security` retention rows. PostgreSQL reports 29 validated CHECKs
  and 30 validated foreign keys, including the new identity CHECK.
- `db:test:prepare` requires listing all configured writable test databases. The run included
  `test_queue_db`; its Solid Queue migration status was `up` both before and after, so no queue
  migration was applied and its schema was not changed.
- **DatabaseConsistency:** `RAILS_ENV=test bundle exec database_consistency` exits 1 with one KEEP
  finding and no `.database_consistency.yml`: `UniqueIndexChecker` does not recognize the custom
  JSON-text uniqueness validator paired with the partial expression index. The six
  `ColumnPresenceChecker` findings are gone. No checker was disabled or excluded. The installed gem
  is 3.1.2; the official checker source filters validators to `kind == :uniqueness` and compares
  validator attributes with parsed index columns, which does not cover this custom expression shape.
  [RubyGems 3.1.2](https://rubygems.org/gems/database_consistency/versions/3.1.2),
  [official `UniqueIndexChecker`](https://github.com/djezzzl/database_consistency/blob/master/lib/database_consistency/checkers/index_checkers/unique_index_checker.rb).
- **Schema drift:** `db:verify_no_schema_drift` exits 1 and lists APP Setting, Chronicle, Occurrence
  and ORG Setting. The migration-built Chronicle dump differs in eight PostgreSQL 18 `pg_dump`
  CHECK-expression renderings (array/type-cast formatting); the other normalized table, index and
  foreign-key definitions match. The other three existing test stores retain the previously recorded
  differences associated with the separate 98-constraint validation proposal. No such additional
  migrations were applied here.

## Remaining work and limits

- KEEP DatabaseConsistency count is **1**, so the zero-warning objective is not met. The remaining
  finding is an upstream checker capability gap, not a missing PostgreSQL uniqueness constraint or
  missing application validation. The model's direct PostgreSQL uniqueness tests remain in place.
- The active spec's separate proposal to validate 98 additional constraints in other KEEP stores
  remains unresolved and unapplied. The related APP Setting, Occurrence and ORG Setting schema
  differences remain.
- The fresh rebuild in this checkpoint covered only test Chronicle. Production and shared database
  row validity, constraint-validation cost and lock impact remain unverified. Migration validation
  failure against intentionally invalid historical data and rollback execution were not simulated.
- Full-suite coverage thresholds remain unmet. ERB Lint, Brakeman and JavaScript checks were not
  rerun because this checkpoint changed only Ruby model/validator code, Chronicle migrations, tests,
  schema dump and Markdown.

No commit or push was made.
