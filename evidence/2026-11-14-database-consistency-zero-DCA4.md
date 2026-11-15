# DatabaseConsistency zero finding — 2026-11-14

## Scope and starting state

- Repository: `umaxica-apps-cosmos-governance`.
- Full HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71` (unchanged; no commit or push).
- The worktree already contained 1,241 status entries at the start of this task. Existing changes in
  `app/models/operator_chronicle.rb`, its uniqueness tests, and the database-consistency spec were
  preserved. Results were therefore evaluated against the current dirty tree.
- No credentials, CI, or schema files were edited. No checker configuration or exclusion was
  created.

## Finding and cause

Before the change, the checker command exited 1 with exactly one finding:

```text
UniqueIndexChecker fail OperatorChronicle uniq_operator_chronicles_sign_flow_halted index is unique in the database but does not have a uniqueness validator
```

This was the Red result for the requested checker acceptance. After the model metadata change, the
same command in the requested Rails test/debug configuration exited 0.

The installed gem is `database_consistency` 3.1.2. Its `UniqueIndexChecker` filters validators by
`kind == :uniqueness` at `unique_index_checker.rb:29-33`, then compares validator attributes and
scope to the parsed index columns at lines 35-43. The matching helper parses expression columns at
`helper.rb:97-113`. Partial predicates are supported: `conditions` are normalized and compared with
the index predicate at `helper.rb:153-193`.

The PostgreSQL index is unchanged:

```sql
UNIQUE (((context ->> 'transaction_public_id'::text)),
        ((context ->> 'halt_generation'::text)))
WHERE event_id = 18
```

The custom validator already checked those exact JSON text values on the writer and used the
`event_id = 18` predicate. The mismatch was its custom validator kind and metadata describing the
source JSONB attribute rather than the two normalized expression terms. Column order and partial
predicate were not the cause.

## Change

`JsonbTextUniquenessValidator` now publishes `:uniqueness`, the two normalized expression terms, the
matching scope term, and an explicit `conditions` proc for `event_id = 18`. Its validation still
reads `context`, checks the same JSONB `->>` values on the writing role, and adds `:taken` for a
duplicate. PostgreSQL's existing unique index remains the concurrent-write authority.

No schema, migration, index, event ID, JSON shape, or checker configuration changed. The
specification was updated with this result and the owner disposition.

## Ownership decision

Governance keeps the independent `chronicle` database and its existing audit history. The accepted
Cosmos split (`adr/cosmos-base-surface-decomposition.md`, decision 1) assigns authentication facts
and their audit writes to Access. `SIGN_FLOW_HALTED` is an authentication-flow event; a current
caller search found no Governance writer for it. Therefore new writes to this event belong to Access
when implemented. Existing Governance rows, event reference, validator and index remain until a
separate history-transfer or retention decision. This is an inference from the accepted split, not
authorization to delete historical audit data.

## Verification

| Check                                           | Result                                                                          |
| ----------------------------------------------- | ------------------------------------------------------------------------------- |
| Baseline DatabaseConsistency                    | Exit 1; 1 finding as recorded above                                             |
| Final DatabaseConsistency in test configuration | Exit 0; 0 findings. The only output was `No configuration files were provided`. |
| `zeitwerk:check`                                | Passed: `All is good!`                                                          |
| Focused OperatorChronicle tests                 | Passed: 6 runs, 56 assertions, 0 failures/errors/skips                          |
| Targeted RuboCop on the two changed Ruby files  | Passed: 2 files, no offenses                                                    |
| Full `bin/rubocop`                              | Exit 1: 6 offenses in four unrelated test files; none in the changed files      |
| Brakeman                                        | Passed: 0 errors, 0 security warnings                                           |
| Full Rails suite                                | 7,596 runs, 50,855 assertions, 31 failures, 0 errors, 0 skips                   |
| `git diff --check`                              | Passed for task changes                                                         |
| Credentials status                              | No credential file diff                                                         |

The six failures from the previous focused diagnostic remain:

- `StepUpCeremonyObservabilityTest#test_unavailable_step-up_start_creates_no_state_or_successful_admission_log_and_exposes_no_identifiers`
- `StaffLifecycleBoundaryTest#test_ORG_withdrawal_stays_informational_for_an_authenticated_local_RP_session`
- `BaseStepUpStartTest` APP and ORG completion/cancellation fail-closed tests
- `BaseSharedRpCellSelectionTest` APP and ORG local-session tests

The remaining 25 failures are in these test files (counts are failure counts):

| Test file                                                                    | Failures |
| ---------------------------------------------------------------------------- | -------: |
| `test/controllers/base/org/identity/birthdates_controller_test.rb`           |        2 |
| `test/controllers/base/org/identity/passkeys_controller_test.rb`             |        1 |
| `test/controllers/base/app/api/v0/preferences/web_pushes_controller_test.rb` |        1 |
| `test/integration/csrf_notification_emission_test.rb`                        |        3 |
| `test/integration/preference_web_csrf_test.rb`                               |       10 |
| `test/integration/jump_rt_return_verification_test.rb`                       |        1 |
| `test/controllers/base/app/identity/totps_controller_test.rb`                |        1 |
| `test/controllers/base/app/api/v0/preferences/theme_controller_test.rb`      |        1 |
| `test/controllers/base/app/identity/withdrawals_controller_test.rb`          |        1 |
| `test/controllers/base/step_up_intent_authority_test.rb`                     |        1 |
| `test/controllers/base/app/identity/passkeys_controller_test.rb`             |        1 |
| `test/controllers/csp_violation_reports_controller_test.rb`                  |        1 |
| `test/integration/preference_browser_api_contract_test.rb`                   |        1 |

An earlier coverage-enabled full run recorded 13 failures without retaining their names. Therefore
the exact overlap with this 31-failure run is not known. These tests do not cover the changed
validator's uniqueness behavior; that behavior is covered by the two focused PostgreSQL tests, but
the remaining full-suite failures are not classified as pre-existing or caused by this change. The
full RuboCop offenses are at lines 21, 74, 89, 49 and 50 of the existing dirty files
`test/controllers/base/org/organizations/memberships_controller_test.rb`,
`test/integration/default_no_store_base_test.rb`,
`test/security/invariants/org_withdrawal_gate_invariant_test.rb`, and
`test/security/invariants/read_only_route_write_invariant_test.rb`.

The full test run caused Rails fixture loading to validate migration-owned constraints in three
disposable test databases. Each target had zero other sessions before reconstruction. The exact
three test databases were individually dropped, recreated and migrated; no other database or Solid
Queue was targeted. Read-only verification after reconstruction found:

| Test database role | Migration receipts | Unvalidated FKs | Unvalidated CHECKs | Other sessions |
| ------------------ | -----------------: | --------------: | -----------------: | -------------: |
| APP Setting        |                 17 |               5 |                  0 |              0 |
| ORG Setting        |                 17 |               9 |                  0 |              0 |
| Occurrence         |                118 |              63 |                  0 |              0 |

The 79 migration-owned FKs remain unchanged; their separate validation decision is outside this work
order. No production or shared database was used.

## Current-tree revalidation (2026-11-14)

The work was resumed at the same full HEAD, `eedf4f51e1e10517ac77381f6a1a03b58b984e71`, with 1,246
existing worktree status entries. No existing work was reset, stashed, or reverted.

The requested command was rerun after the test-database restoration:
`RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` exited **0** with **0
findings** and **0 error lines**. It printed only `No configuration files were provided`; no checker
configuration or exclusion was added.

With the stale `POSTGRESQL_TEST_PREPARE_DATABASES` value unset (the initial focused attempt failed
Rails initialization with `Umaxica::TestEnvironment::ConfigurationError`), the two focused
PostgreSQL uniqueness test files passed **6 runs / 56 assertions / 0 failures / 0 errors / 0
skips**. `bin/rails zeitwerk:check` passed. The targeted RuboCop run for the model, validator and
those two tests exited **0**. The full `bin/rubocop` run exited **1** after inspecting 2,873 files
and finding **6 offenses** (5 autocorrectable) in the already-dirty repository; none were in the
four targeted files. Brakeman with `--quiet --no-pager --exit-on-warn --exit-on-error` exited **0**.

The exact full command `bin/rails test`, also with the stale preparation variable unset, completed
**7,597 runs / 50,938 assertions / 13 failures / 0 errors / 0 skips**. The safe output filter
retained only the aggregate, so the failure names were not reclassified in this revalidation. The
focused uniqueness tests passed, and no failure was shown to involve the changed validator; the
remaining full-suite failures are therefore reported as unresolved rather than attributed to this
change.

The full test run validated the migration-owned foreign keys in the disposable APP Setting, ORG
Setting and Occurrence test databases. A read-only catalog check confirmed **0 other sessions** in
each before recovery. Only these three named test databases were individually dropped, recreated and
migrated with their existing tasks. The post-recovery read-only check found:

| Test database | Migration receipts | Unvalidated FKs | Unvalidated CHECKs | Other sessions |
| ------------- | -----------------: | --------------: | -----------------: | -------------: |
| APP Setting   |                 17 |               5 |                  0 |              0 |
| ORG Setting   |                 17 |               9 |                  0 |              0 |
| Occurrence    |                118 |              63 |                  0 |              0 |

No production, shared, Solid Queue or other database was targeted. `config/credentials` has no diff.
No source schema, migration, or checker configuration was changed for this finding. The aggregate
suite failures and six full-repository RuboCop offenses remain outside the verified uniqueness fix;
the checker finding itself remains at zero.

## Requested work-order revalidation (2026-11-14)

The work order was rechecked at the same full HEAD, `eedf4f51e1e10517ac77381f6a1a03b58b984e71`, with
1,253 existing worktree status entries. No commit or push occurred. The model, validator, focused
tests, and database-consistency spec already contained the work-order change; they were not reset or
replaced.

The baseline Red result remains the one finding recorded above. Current Green verification:

| Command                                                                                                                      | Result                                                           |
| ---------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` (stale test-preparation variable and `COVERAGE` unset) | Exit 0; 0 findings; no configuration file or exclusion           |
| Focused `OperatorChronicle` PostgreSQL model tests                                                                           | 6 runs / 56 assertions / 0 failures / 0 errors / 0 skips         |
| `bin/rails zeitwerk:check`                                                                                                   | Exit 0                                                           |
| Targeted RuboCop for the model, validator, and two uniqueness tests                                                          | Exit 0                                                           |
| Full `bin/rubocop`                                                                                                           | Exit 1; 2,873 files, 6 offenses, none in the targeted files      |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                             | Exit 0                                                           |
| `bin/rails test`                                                                                                             | 7,599 runs / 51,015 assertions / 2 failures / 0 errors / 0 skips |
| `git diff --check` for the work-order paths                                                                                  | Exit 0                                                           |

The two full-suite failures are the existing APP and ORG local-session cases in
`BaseSharedRpCellSelectionTest`; its isolated file run also had 2 runs / 8 assertions / 2 failures.
They exercise RP session admission and unavailable Access issuance, not the Chronicle validator. The
unrelated full RuboCop offenses remain in the dirty repository baseline; the targeted files pass.

The repeated full suite changed validation state in only the disposable APP Setting, ORG Setting,
and Occurrence test databases. After confirming zero other sessions, those three databases alone
were rebuilt by their individual `db:drop:<writer>`, `db:create:<writer>`, and `db:migrate:<writer>`
tasks. Post-rebuild read-only catalog results:

| Test store  | Migration receipts | Unvalidated FKs | Unvalidated CHECKs | Other sessions |
| ----------- | -----------------: | --------------: | -----------------: | -------------: |
| APP Setting |            17 / 17 |               5 |                  0 |              0 |
| ORG Setting |            17 / 17 |               9 |                  0 |              0 |
| Occurrence  |          118 / 118 |              63 |                  0 |              0 |
| Chronicle   |            34 / 34 |               0 |                  0 |              0 |

Final post-rebuild DatabaseConsistency rerun again exited 0 with 0 findings. Chronicle's index and
schema were unchanged. No production, shared, Queue, or other database was operated on.
`config/credentials` has no diff; no DatabaseConsistency configuration, exclusion, CI change,
migration, index change, or schema change was added for this work order.

The installed checker is `database_consistency` 3.1.2. In the bundled source,
`UniqueIndexChecker#valid?` filters on validator `kind` at `unique_index_checker.rb:29-33`, and
`validator_matches?` compares normalized expression columns and partial conditions at lines 35-39.
`Helper#conditions_where_sql` and `conditions_match_index?` support the partial predicate at
`helper.rb:153-163` and `182-193`. Thus the partial condition was expressible; the mismatch was the
custom kind and metadata naming `context` rather than the two index expressions. The current
validator publishes the expression columns, matching scope, and `event_id = 18` conditions while
checking the same JSON text values on the writer. The PostgreSQL unique index remains authoritative
for concurrent writes.

Ownership disposition: the accepted `adr/cosmos-base-surface-decomposition.md` keeps independent
audit records on both sides and assigns authentication facts and their audit writes to Access.
Therefore Governance retains its separate Chronicle database, existing `SIGN_FLOW_HALTED` event
reference, and historical rows; new writes for this authentication event belong to Access when its
path is implemented. This is an ownership inference, not authorization to move or delete history.

## Latest requested-plan verification (2026-11-14)

The work order `plans/2026-11-14-database-consistency-zero-work-order.md` was rechecked at HEAD
`eedf4f51e1e10517ac77381f6a1a03b58b984e71`. The shared worktree had **1,252 changed or untracked
paths**. The validator, model declaration, PostgreSQL tests, and earlier implementation evidence
were already present before this recheck; no application, test, migration, schema, or CI source was
changed in this continuation. No commit or push occurred.

The recorded Red result remains **1 finding** before the validator metadata correction (see the
earlier verification sections in this record). At the start of this recheck the current tree already
returned **0 findings**, and the final rerun after tests and test-database restoration also returned
**0 findings**:

| Check                                                                                    | Result                                                                      |
| ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` at recheck start   | Exit 0; 0 findings                                                          |
| Same checker after the full test run and database restoration                            | Exit 0; 0 findings                                                          |
| Focused `OperatorChronicle` PostgreSQL tests                                             | 6 runs / 56 assertions / 0 failures / 0 errors / 0 skips                    |
| Targeted RuboCop on the model, validator and focused tests                               | Exit 0; 4 files, no offenses                                                |
| `bin/rails zeitwerk:check`                                                               | Exit 0; eager load passed                                                   |
| Full `bin/rubocop`                                                                       | Exit 1; 6 offenses in four unrelated dirty test files, none in target files |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                         | Exit 0; 0 errors / 0 security warnings                                      |
| `env -u POSTGRESQL_TEST_PREPARE_DATABASES -u COVERAGE PARALLEL_WORKERS=1 bin/rails test` | 7,603 runs / 51,022 assertions / 3 failures / 0 errors / 0 skips            |
| `git diff --check`                                                                       | Exit 0                                                                      |

The three full-suite failures were
`JumpRtReturnVerificationTest#test_a_Jump_return_token_on_an_unsafe_Base_request_does_not_exempt_it_from_CSRF`,
`CspViolationReportsControllerTest#test_Base_CSP_intake_accepts_browser_reports_without_issuing_credentials`,
and
`Base::App::Api::V0::Preferences::ThemeControllerTest#test_PATCH_update_creates_the_actor_preference_record_on_a_signed`.
These same tests were listed in an earlier full-suite report in this evidence. None exercises
`OperatorChronicle` or `JsonbTextUniquenessValidator`. The validator correction was already present
at the start of this recheck, and the dirty tree prevents a clean baseline comparison, so their
provenance relative to the original correction remains unverified; they are unrelated to the changed
behavior.

After the full suite, a read-only catalog query found 0 unvalidated FKs in APP Setting, ORG Setting,
Occurrence and Chronicle. Before reconstruction, each exact target had 0 other database sessions.
Only the three disposable test stores whose migration-owned FK states changed were individually
dropped, recreated and migrated. The final receipts and constraint states are APP Setting **17
migrations / 5 unvalidated FKs / 0 unvalidated CHECKs**, ORG Setting **17 / 9 / 0**, Occurrence
**118 / 63 / 0**, and Chronicle **34 / 0 / 0**. No Queue, production, shared, or other database was
targeted. The three corresponding structure dumps and `config/credentials` have no worktree diff.

The locked and installed checker remains `database_consistency` **3.1.2**. Its
`UniqueIndexChecker#valid?` selects `kind == :uniqueness` at `unique_index_checker.rb:29-33`,
compares expression columns and scope at lines 35-39, and delegates partial-predicate comparison to
`Helper#conditions_match_index?` at `helper.rb:182-193`. Therefore a partial predicate is supported.
The earlier failure came from the custom validator's kind and source-column metadata, not the
index's expression order or partial condition. The existing validator reports the two normalized
JSON-text index expressions, the matching scope, and `event_id = 18`, while continuing to validate
the same JSON text values on the writing connection. The PostgreSQL index remains unchanged and
authoritative for concurrent inserts; no checker exclusion, schema change or migration was added.

Ownership remains as previously recorded: Governance owns its independent Chronicle store and
existing audit history; the accepted surface split assigns authentication facts and their audit
writes to Access. The `SIGN_FLOW_HALTED` event has no current Governance writer, so future writes
are Access-owned. Existing Governance event references and rows remain until a separately scoped
history-transfer or retention decision. No lifecycle or deletion rule changed, so no diagram or
checklist change was required. `config/credentials` is unchanged.
