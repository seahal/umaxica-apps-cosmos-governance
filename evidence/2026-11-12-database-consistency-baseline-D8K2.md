# Governance database consistency baseline

Revision: 43db4906742db2fb13b238c9ccde378e4e1583b4

Extensive pre-existing uncommitted split changes affected all observations. The current worktree,
not the committed revision alone, was tested. Scope is Governance only, per owner clarification.
See `specs/governance-database-consistency/spec.md` for classification and open acceptance.

## Observations

- `bundle check`: dependencies satisfied; local database_consistency fork version 3.0.16.
- PostgreSQL primary accepts connections outside the restricted sandbox. Test runner reports
  PostgreSQL 18.6. Later execution permissions allow direct access.
- `RAILS_ENV=test bundle exec database_consistency`: exit 1, no configuration file supplied.
  Baseline has 719 failure report lines. Mapping report model names to eager-loaded concrete
  ApplicationRecord connection configurations yields 116 KEEP report lines: app_zenith 53,
  org_zenith 29, avatar 9, rp_base_app 9, rp_base_org 15, rp_tech_org 1. Primary has no report lines.
  Report lines may aggregate several offenses; these numbers are not individual constraint counts.
- Other report lines: publishing 432, op_base_app 93, op_base_org 70, chronicle 2, and one each
  for rp_core_app, rp_core_org, rp_warp_app, rp_warp_org, rp_palm_app, rp_edit_org.
- No Solid Queue report lines appeared. This does not establish complete framework-model coverage.
- The standard Rails test preparation reports a migration scope including every configured test DB.
  No schema changes were introduced at baseline; future reconstruction must be explicitly limited
  to KEEP, without invoking db:drop:all.

## First verified behavior unit

`AvatarTransferReservation` lacked model enforcement of its existing database five-day maximum.
New microsecond boundary tests first produced 17 tests / 61 assertions / one failure because
five days plus one microsecond had no expiry error. The first test draft used unsupported
`Integer#microsecond`; this was corrected to exact Rational seconds before the behavioral Red.

Model validation now enforces the existing maximum. The SQL-boundary test bypasses model validation
with `save!(validate: false)` and still asserts database rejection above five days. No migration,
constraint removal, checker exclusion, or CI change was made.

After extending coverage to the lower interval boundary: 20 tests, 67 assertions, zero failures,
errors or skips. Coverage for app/models/avatar_transfer_reservation.rb: line 100%, branch 100%,
method 100%. The focused coverage command exits 2 because suite-wide coverage thresholds are not
met by this partial suite. This is not a successful whole-repository coverage gate.

Full audit, warning elimination, changed-schema reconstruction and integration acceptance remain open.

## Additional completed validation units

- AvatarLifecycleState now declares the inverse `avatars` with `dependent: :restrict_with_error`;
  Avatar declares the matching inverse. Red reproduced an InvalidForeignKey during `destroy`.
  Green asserts a safe application refusal and retained rows, and separately asserts that direct
  `delete` still raises InvalidForeignKey. Lifecycle/reservation combined regression: 44 tests,
  244 assertions, zero failures/errors/skips. RuboCop passed all five related files.
- BureauOwnershipTransferRequest, AgentOwnershipTransferRequest,
  EnterpriseOwnershipTransferRequest and ClientPersonaOwnershipTransferRequest now require both
  existing NOT NULL timestamps at validation. Red: eight nil-input failures; Green: 20 focused
  tests / 32 assertions. Related regression: 32 tests / 148 assertions, zero failures/errors/skips.
  All five changed files passed RuboCop. No persistent shape change was needed.

## Empty KEEP database reconstruction

Executed Rails MigrationContext against new receipt-owned PostgreSQL databases, never schema loads or clones. Existing configured databases and excluded databases were not dropped.

| Connection | Isolated database | Migration files/applied | Pending | Result |
| --- | --- | --- | --- | --- |
| primary | test_dbc_20261112_governance_primary | 2/2 | 0 | migrated |
| avatar | test_dbc_20261112_governance_avatar | 92/92 | 0 | migrated |
| app_zenith | test_dbc_20261112_governance_app_zenith | 438/438 | 0 | migrated |
| org_zenith | test_dbc_20261112_governance_org_zenith | 302/302 | 0 | migrated |
| rp_base_app | test_dbc_20261112_governance_rp_base_app | 22/22 | 0 | migrated |
| rp_base_org | test_dbc_20261112_governance_rp_base_org | 26/26 | 0 | migrated |
| rp_tech_org | test_dbc_20261112_governance_rp_tech_org | 8/8 | 0 | migrated |

The run completed 2026-11-12T11:44:21Z, exit 0. This proves reconstruction for that worktree snapshot; subsequent migrations require another empty reconstruction. Dump equality is not implied.

## Subsequent verified boundaries

- Configured writer count is 26 (including queue), with 28 migration paths. An initial delegated
  count of 24 was inaccurate; the effective Rails configuration supplies the corrected count.
- After validation of all 42 existing constraints, normalized schema dumps from all seven existing
  test databases match their independently migration-built counterparts. Identity-dependent HMAC
  role names and deliberate logged/unlogged test storage differences use the repository's existing
  SchemaDriftVerification normalization, not ignored semantic changes.
- Mid-cycle unconfigured checker capture has 42 KEEP grouped failure lines, down from 116. This
  is an intermediate result while approved schema units and further model work remain underway;
  no final zero-warning claim is made.
- Combined first implementation aggregate: 171 tests / 840 assertions / zero failures, errors or
  skips. Its coverage process exits 2 on unchanged suite-wide thresholds because it is a partial
  suite. The per-file expiry model previously measured 100% line/branch/method coverage.
- Core bridge cardinality plus migrated caller/erasure regressions: 147 tests / 469 assertions /
  zero failures, errors or skips. A second same-actor RP bridge was previously left behind by
  has_one destruction; plural has_many now represents the existing composite-key contract.
- RP step-up implementation/regression: 38 tests / 308 assertions / zero failures, errors or skips.
  Independent two-database up/down/up preserves row hashes and restores the original definitions
  on down; final four history FKs are validated RESTRICT and four redundant indexes are absent.
  See S9R4 evidence. This changes no RP source retention duration or purge workflow.

## Removal-task checkpoint and durable checker patch

The owner prioritized removal of ten non-Governance connection families, with surviving schemas
frozen during that removal. The remaining topology has 16 writers including excluded Queue.
The latest standard checker capture reports **35 retained failures**, exit 1, with no Queue
failures reported. This remains an intermediate observation, not completion.

The ignored local checker-fork changes are preserved as the reviewable patch
`patches/database-consistency-postgresql-validation-semantics.patch`, based on fork HEAD
`d5d1781f3d642b428d6a9654099b0cd96ce52fd8`. It includes the added regression spec and preserves
checks rather than excluding Models/connections. The prior 335-spec successful checker run
predates this packaging-only step; no new test success is claimed here.

## Receipt and reservation continuation

Added uniqueness validations to APP/ORG identity events, identifier-rotation audits and the ORG IAM operation receipt. The identity-stop recorder now uses a nested transaction and the owning database clock. Avatar reservation expiry uses a fixed 120-hour duration across daylight-saving transitions.

The four-file PostgreSQL regression run improved from 31 tests / 82 assertions / 13 failures to **31 tests / 149 assertions / 2 failures**, with zero errors or skips. Both remaining failures concern missing Avatar reservation uniqueness validations; this unit remains incomplete. Lint, coverage, full regression and the consistency checker have not been rerun after these edits.

## Reservation uniqueness continuation

Added a global idempotency-key validation and a pending-only avatar validation, preserving the PostgreSQL unique indexes. The reservation creator retries only matching uniqueness validation failures or the existing named database conflicts; unrelated validation failures still propagate. Added the localized attribute label needed to render validation errors.

The focused PostgreSQL regression rerun passed: **31 tests, 161 assertions, zero failures/errors/skips**. The preceding run found missing error-label translations; these were corrected. RuboCop on the eight affected production Ruby files passed. Full regression, coverage, schema drift verification and the final checker remain outstanding.

## Audit outbox uniqueness continuation

Added event identity uniqueness validations to five retained audit outbox models. Passkey registration operation uniqueness follows the existing partial indexes: only the two registration events and non-NULL, nonempty references are included, including whitespace. PostgreSQL tests cover duplicate writes, SQL bypass, ordinary events, realm separation and registration rollback. After correcting two test fixtures, the focused run passed: **5 tests, 102 assertions, zero failures/errors/skips**. The two passkey models were formatted with RuboCop; broader regression, coverage and the checker remain outstanding.

## Latest checker and audit delivery regression

After the audit-outbox validation changes, the focused outbox and delivery-job regression passed: **27 tests, 275 assertions, zero failures/errors/skips**. The unconfigured standard checker exited 1 with **25 failure lines**, down from the previous 35-line checkpoint. This count includes two missing-index and two missing-validator reports for the Passkey registration partial indexes: the model guard excludes NULL and empty references while the index predicate includes those exclusions alongside event types. Whether the checker can prove this equivalent contract remains to be investigated; no checker exclusion was added. Remaining dependent-association and other uniqueness reports also remain open. Solid Queue produced no reported failure lines in this run.

## Client profile inverse association

The `Client#clients` alias now rejects deletion when profiles remain, matching the already-approved mandatory profile owner, the `Client#client_profiles` inverse and the migration's RESTRICT foreign key. The existing public parent-deletion and direct SQL regression passed: **9 tests, 56 assertions, zero failures/errors/skips**. The pre-existing checker failure identified the conflicting nullify association; the checker has not yet been rerun after this correction.

## Checker after Client profile inverse correction

The standard unconfigured checker was rerun against the current test environment. It exited 1 and reported **24 failure lines**, one fewer than the previous 25; the Client profile nullify/RESTRICT mismatch is no longer reported. The remaining reports include nine missing dependent associations and four reports involving the two Passkey registration partial indexes. No Solid Queue failure line appeared. The checker does not establish that the unvalidated foreign keys have been validated or that all direct PostgreSQL invariants have been tested.

## Processor erasure notification uniqueness

Added model validation matching the existing `(client_privacy_request_id, processor_key)` unique index. Red was confirmed for a duplicate; direct PostgreSQL bypass and a second request were exercised. The focused model and job regression passed: **5 tests, 22 assertions, zero failures/errors/skips**. The initial Green attempt exposed an invalid test processor key; the test was corrected to use the same valid processor on a different request. Final checker and broader coverage remain outstanding.

## External identity receipt retention

Added a restrictive inverse association for social-link source receipts, matching the existing PostgreSQL RESTRICT foreign key and preserving the receipt. The new test initially failed because deletion reached the database; after the change it verifies model refusal and direct SQL RESTRICT. The focused model suite passed: **4 tests, 19 assertions, zero failures/errors/skips**. The first follow-up exposed the actual PostgreSQL `RestrictViolation` exception type, which the SQL assertion now checks. Broader regression and final checker verification remain outstanding.

## Checker after processor and social receipt changes

The unconfigured standard checker was rerun after the processor uniqueness and social receipt inverse changes. It exited 1 with **22 failure lines**, down from 24 at the prior checkpoint. Neither of those two findings is present. Remaining findings include the Passkey partial-index equivalence reports and retention-sensitive dependent-association reports. No Solid Queue failure was reported. This is an intermediate result; schema validation, coverage and full regression remain incomplete.

## Passkey registration index predicates

Made the existing registration uniqueness validation query explicitly use the complete existing partial-index predicate, including the non-NULL and nonempty operation reference. The incoming-record guard remains unchanged; whitespace is still indexed. PostgreSQL regression passed: **5 tests, 102 assertions, zero failures/errors/skips**. RuboCop passed for both models. The unconfigured checker now reports **18 failure lines**, down from 22, and no longer reports the four Passkey partial-index findings. No Solid Queue failure was reported. Overall completion and broader regression remain outstanding.

## Client chronicle event identity

Added model uniqueness validation for non-NULL event UUIDs, retaining multiple NULL legacy UUIDs as permitted by the existing PostgreSQL index. The duplicate model case was confirmed Red before implementation. The PostgreSQL test also bypasses validation to verify the unique index. Model and activity-presenter regression passed: **15 tests, 87 assertions, zero failures/errors/skips**. The checker has not been rerun after this change.

## Active actor preference uniqueness

Added validations matching the existing active-only partial indexes for Client and Operator preferences; retired history remains permitted. Two validation tests failed before the change. Existing SQL constraint tests still bypass validation to check the database. The model regression passed: **16 tests, 72 assertions, zero failures/errors/skips**. The standard checker now reports **15 failure lines**, down from 17; no Solid Queue failure was reported. Full regression and coverage remain outstanding.

## Open authentication-method effects

Added validations matching the existing APP and ORG partial unique indexes for an open `(principal_public_id, authentication_method)` effect. Ended history remains allowed. The new duplicate validations were confirmed Red, and direct PostgreSQL bypass plus closing and replacement were tested. Model and apply-order regression passed: **13 tests, 70 assertions, zero failures/errors/skips**. The standard checker reported **13 failure lines**, down from 15. Full coverage and broader regression remain outstanding.

## Open identifier effects

Added APP/ORG validation matching the existing partial uniqueness indexes on open identifier effects. Ended history remains valid. The duplicate cases were Red first; direct PostgreSQL duplicate rejection, closing and replacement were verified. Related model and case ordering regression passed: **16 tests, 102 assertions, zero failures/errors/skips**. RuboCop corrected two test formatting offenses. The standard checker now reports **11 failure lines**, down from 13; no Solid Queue failure was reported. The accepted ADR contains a conflicting HMAC rationale about simultaneous cases; the existing index and its explicit D8 close-before-apply decision were preserved, and the conflict requires documentation handoff. Full regression and coverage remain outstanding.

## Secret issuance retention

Added a restrictive inverse association from ClientSecretIssuance to its credentials, matching the existing composite foreign key. The test first reproduced the database-only refusal, then verified the model refusal and direct SQL foreign-key rejection. The focused issuance and credential regression passed: **22 tests, 266 assertions, zero failures/errors/skips**. The checker now reports **10 failure lines**, down from 11. RuboCop corrected nine formatting offenses in the touched files. Full regression and coverage remain outstanding.

## Registration completion ownership

Added a restrictive Client inverse for immutable registration completion records, matching the existing PostgreSQL RESTRICT foreign key. The new association test was Red before the change and verifies that direct SQL cannot delete the owner while the receipt exists. Related regression passed: **13 tests, 78 assertions, zero failures/errors/skips**. RuboCop corrected one test formatting offense. The standard checker reports **9 failure lines**, down from 10; full regression and coverage remain outstanding.

## Secret claim identifiers

Added uniqueness validations for non-NULL claim operation and sign-in flow references, matching the existing independent PostgreSQL indexes. The test was Red before the change and verifies both direct SQL duplicate rejection and retained NULL identifiers. Credential regressions passed: **22 tests, 222 assertions, zero failures/errors/skips**. RuboCop corrected two test formatting offenses. The standard checker reports **7 failure lines**, down from 9; full regression and coverage remain outstanding.

## Operator identifier-history retention

Added restrictive Operator inverses for email and telephone history, before other dependent callbacks, matching their existing RESTRICT foreign keys. The new test initially exposed a strict-loading error before the refusal; it now verifies both model refusal and direct PostgreSQL RESTRICT on newly created Operators. Related retention tests passed: **6 tests, 54 assertions, zero failures/errors/skips**. The standard checker reports **5 failure lines**, down from 7. RuboCop corrected one test formatting offense. Full regression and coverage remain outstanding.

## Client ownership of Secret issuances

Added a restrictive Client inverse for Secret issuance records, matching the existing foreign key. The new association test was Red before implementation and verifies direct SQL parent deletion is rejected. Issuance and credential regression passed: **24 tests, 279 assertions, zero failures/errors/skips**; RuboCop passed for the three touched Ruby files. The standard checker reports **4 failure lines**, down from 5. Full regression and coverage remain outstanding.

## Recovery ceremony ownership

Added a restrictive Client inverse for enforcement recovery ceremonies, matching the existing foreign key. The association test was Red before implementation and direct SQL parent deletion remains rejected. The focused model and recovery operation regression passed: **3 tests, 24 assertions, zero failures/errors/skips**. The standard checker reports **3 failure lines**, down from 4. RuboCop corrected one alignment offense. Full regression and coverage remain outstanding.

## Client identifier-history lifecycle

Added restrictive email and telephone history inverses after the existing authorized-erasure callback; the callback clears loaded association caches after deletion. Tests cover a recoverable Client retaining history and an eligible Client erasing preloaded history. The association test was Red before implementation. Related retention regression passed: **7 tests, 56 assertions, zero failures/errors/skips**. The standard checker now reports **one failure line**, the OperatorChronicle expression index, down from three. RuboCop corrected one test formatting offense. Direct SQL history deletion and full rollback combinations need further verification; full regression and coverage remain outstanding.

## Operator chronicle expression uniqueness

Added a model validation using PostgreSQL JSON text extraction for the existing event 18 transaction/generation expression index. It preserves NULL expression semantics, other event types and distinct generations; the index remains the race-safe authority. The duplicate test was Red before implementation. Model regression passed: **17 tests, 49 assertions, zero failures/errors/skips**; RuboCop corrected test formatting. The checker implementation currently matches only conventional attribute uniqueness validators, so its expression-index report is not yet resolved or excluded. Full checker, regression and coverage remain outstanding.

## Current cross-domain regression and schema drift

Seven focused model files covering history retention, audit outboxes, enforcement and the OperatorChronicle expression constraint passed: **28 tests, 221 assertions, zero failures/errors/skips**. An added direct SQL Client history deletion test passed with the existing retention test: **2 tests, 14 assertions, zero failures/errors/skips**; PostgreSQL raised RESTRICT and preserved the rows.

`RAILS_ENV=test bin/rails db:verify_no_schema_drift` exited 1 and reported nine schema dump paths: app_setting, app_zenith, avatar, chronicle, occurrence, org_setting, org_zenith, rp_base_app and rp_base_org. This command compares against committed dumps, while the worktree already contains extensive uncommitted migration work. The current dump-versus-live and migration ownership differences still require investigation; no schema dump was overwritten by this check. The exact failure output is retained under `tmp/original-consistency/schema-drift-current.txt`.

## Working-tree schema comparison

A separate read-only comparison used the existing schema normalization routine against the **working-tree** dumps, rather than adding `git diff` results. Of 15 retained writer configurations, six match (primary, storage, com_setting, app_signal, org_signal, rp_tech_org); nine differ (app_zenith, org_zenith, app_setting, org_setting, rp_base_app, rp_base_org, occurrence, chronicle, avatar). Queue was excluded. The normalized dump pairs are in `tmp/original-consistency/schema-comparison/`; no repository dump was overwritten.

Examples: the test APP Zenith database includes approved owner NOT NULL, bigint and validation changes absent from its working-tree dump. In Occurrence, the test database has validated foreign keys where the working-tree dump records NOT VALID; the separate fresh-migration audit previously found 63 unvalidated Occurrence foreign keys. Thus a passing test-database state alone does not prove fresh migration output and dumps agree. The cause and safe dump generation/reconciliation remain open; no retained or shared database was reset.

## Approved migration schema dumps reconciled

Compared nine differing working-tree dumps against independent empty-database migration builds and the existing test databases. Five (APP Zenith, ORG Zenith, Avatar, RP Base APP and RP Base ORG) had identical fresh-migration and test database schemas but stale working-tree dumps. The differences were reviewed against the previously approved validation, identifier, index and RESTRICT migrations. Preserved the exact five original working-tree dumps and hashes under `tmp/original-consistency/schema-dump-backup/`, then generated the five dumps using the corresponding explicit Rails `db:schema:dump:<database>` tasks. No database schema or data was changed by dumping.

After generation, all five normalized working-tree dumps match both their fresh migration builds and the existing test databases. The remaining four differences (APP Setting, ORG Setting, Occurrence, Chronicle) are between their current test databases and both their working-tree dumps and independently rebuilt fresh databases; their retained NOT VALID foreign keys remain a separate unresolved unit. The first temporary comparison attempt was invalid because the isolated configuration deliberately disables schema dumping; it was corrected using a temporary configuration override without modifying the repository DB settings. Queue was excluded. The repository-wide drift task also flags uncommitted dump changes by design, so its final result is not yet a clean baseline claim.

## Expression-index JSON equivalence

Extended the OperatorChronicle regression to verify that JSON number `1` and string `"1"` collide under PostgreSQL `->>` text extraction, and that validating the original persisted row does not conflict with itself. Model regression passed: **17 tests, 53 assertions, zero failures/errors/skips**. The model retains parameterized PostgreSQL JSON extraction; no checker was disabled. The expression-index checker limitation and final coverage remain open. The workflow patch still applies cleanly in check mode, but `.github` remains a read-only mount, so it was not applied.

## Client identifier-history rollback

Added a PostgreSQL transaction test that deletes an eligible Client and its email/telephone history, then rolls the transaction back and verifies that the owner and both history rows return. Combined model and retention-job tests passed: **8 tests, 64 assertions, zero failures/errors/skips**. RuboCop was applied to the new test. This verifies transaction rollback; it does not yet test every possible later dependent callback failure.

## Operator chronicle duplicate error delivery

Confirmed the expression index cannot be represented by the fork's current conventional attribute-uniqueness matcher; no report was suppressed or checker bypass added. A new public `save!` test exposed that a duplicate raised a missing-translation error instead of `RecordInvalid`. Added the context attribute labels in both locales. The focused model regression passed: **17 tests, 54 assertions, zero failures/errors/skips**; focused RuboCop passed. The expression-index checker report itself remains open.

## Full-suite checkpoint after consistency changes

`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test` completed with **7,645 tests, 51,064 assertions, 6 failures, zero errors/skips**. One failure was caused by the new OperatorChronicle model validation preceding the existing direct-index assertion; the existing test now separately checks model refusal and bypasses validation for the unchanged database uniqueness assertion. After that correction and formatting, the affected regression passed: **25 tests, 201 assertions, zero failures/errors/skips**. The full suite was not rerun after the correction.

The other five observed failures concern existing CSP cookie behavior (one) and preference timezone/reference recovery behavior (four); unchanged source alone does not prove their historical test outcome, and they remain unresolved. `bin/rubocop` was rerun after targeted formatting: **2,919 files, no offenses**. `bundle exec erb_lint --lint-all`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` and `bun run check` all exited 0. Coverage was disabled for this full run.

## Preference timezone request transport

The previously failing timezone tampering tests issued successive HTTP requests even though the preference cookie is Secure. They therefore did not send the prior browser preference on later requests. Updated those tests to use HTTPS and retained all existing option and state assertions. The full test file passed: **5 tests, 35 assertions, zero failures/errors/skips**; focused RuboCop passed. This resolves two observed full-suite failures in the focused run; the full suite has not yet been rerun.

## Preference audit reference recovery investigation

Re-ran the two failing reference-recovery integration tests with HTTPS. Both still failed (2 tests, 4 assertions, 2 failures); the temporary HTTPS-only edits were removed. Current APP/ORG anonymous preference creation ensures setting status and option references but does not invoke the COM-specific Chronicle audit creation path. The tests expect missing APP/ORG Chronicle level rows to be restored by a preference write. The expected current audit contract and safe cross-database failure ordering require further investigation; assertions were not removed or weakened.

Correction to the earlier full-suite note: `app/controllers/concerns/preference_write_boundary.rb` was already dirty in the task baseline and also has removal-related differences from HEAD. Therefore, unchanged source cannot establish that these two failures predate this task; their cause remains unclassified until the baseline behavior and accepted contract are reconciled. No source fix or successful regression is claimed.

## Preference audit failure source comparison

Compared the complete current `create_anonymous_realm_preference!` and `persist_app_org_preference!` method bodies with full HEAD `43db4906742db2fb13b238c9ccde378e4e1583b4`; both are byte-identical. The two failing integration tests are also unchanged relative to HEAD. The APP/ORG creation method does not initialize Chronicle event or level rows, whereas COM calls the reference-default and audit writer path. This narrows the discrepancy to an existing method/test contract mismatch in the committed revision, but does not establish the exact pre-removal dirty-worktree behavior or authorize inventing a cross-database audit transaction. Both failing assertions remain intact. The earlier HTTPS experiment did not resolve either failure.

## CSP report cookie failure investigation

The existing CSP endpoint test expects both ordinary and XHR browser reports to receive no cookies. The report controllers inherit surface-specific `ActionController::Base` bare controllers and already explicitly skip Rails forgery verification for their create-only telemetry action. Inertia Rails 3.23.0 globally installs an anonymous `after_action` on `ActionController::Base`; for HTML or XHR requests with forgery protection enabled, it calls `form_authenticity_token` and writes `XSRF-TOKEN`. Rails session middleware then persists the generated CSRF token, producing the observed session cookie. This explains the two cookie names in the failing test.

A broad forgery-protection override or global callback change would change unrelated security boundaries, and the Inertia callback is an anonymous block rather than a named callback. No such bypass or assertion weakening was introduced. A scoped architecture-level resolution and regression verification remain open; the issue is not established as caused by database changes.

## Operator chronicle validation connection

A role-observing test confirmed Red: when called under the reading role, expression uniqueness validation queried the reading connection. Changed the duplicate lookup to the Chronicle writing connection to avoid a stale-replica decision; database uniqueness remains the concurrency authority. Model and existing index regression passed: **21 tests, 66 assertions, zero failures/errors/skips**; focused RuboCop passed. The checker expression-index finding remains open and no checker was disabled.

### Focused regression recheck

With the existing uncommitted worktree at HEAD `43db4906742db2fb13b238c9ccde378e4e1583b4`, ran `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test test/integration/preference_reference_defaults_recovery_test.rb test/controllers/csp_violation_reports_controller_test.rb`: **13 tests, 34 assertions, 3 failures, 0 errors, 0 skips**. Both APP/ORG preference recovery tests still observe a missing audit level after the write; the CSP credential-free intake test still observes `XSRF-TOKEN` and session cookies. The installed Inertia Rails 3.23.0 controller concern registers an after-action on `ActionController::Base` which issues an XSRF cookie for HTML or XHR requests when forgery protection is enabled. This identifies the immediate CSP cookie source, but no security-sensitive callback change or audit contract change has been validated. The earlier full-suite result has not been superseded by another full run.

### CSP report cookie regression

The existing credential-free CSP intake assertion failed before the change with both `XSRF-TOKEN` and `session` cookies. Expanded its coverage to the Tech Org host as well as the three Base hosts. The CSP report concern now reflects its existing create-only CSRF exemption in `protect_against_forgery?`, preventing the inherited Inertia after-action from creating a CSRF token and session for this endpoint; other actions defer to Rails. The test uses the surviving Base App root for the ordinary-page control, because the previously used `/sign` route was removed. It still verifies that ordinary pages issue the XSRF cookie and that cross-site preference changes fail CSRF verification.

`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test test/controllers/csp_violation_reports_controller_test.rb test/controllers/base/app/bare_controller_test.rb test/services/csp_violation_report_intake_test.rb test/subscribers/csp_violation_subscriber_test.rb`: **28 tests, 259 assertions, 0 failures/errors/skips**. `bin/rubocop app/controllers/concerns/csp_violation_report.rb test/controllers/csp_violation_reports_controller_test.rb`: **2 files, no offenses**. A complete test suite after this change has not yet been run.

### Full Rails regression after CSP repair

`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test` completed with **7,645 tests, 51,210 assertions, 2 failures, 0 errors and 0 skips**. Both failures are the APP and ORG missing preference-audit-level recovery tests documented above; the CSP intake test and the previously corrected failures passed in this run. Coverage was disabled and is not established by this result. The preference lifecycle purger acquires the Chronicle advisory lock before entering the setting transaction, so any audit repair must preserve that order and account for the two independent database commits.

### APP and ORG preference audit restoration

The two existing recovery tests were strengthened to check the corresponding creation audit subject and event. A new failure-path test injects an audit persistence failure for both realms and checks that the new anonymous preference is rolled back, no anonymous preference token is emitted, and the response is 503. Before implementation the focused run had **3 tests, 3 failures**, including creation of a preference despite the injected failure.

APP and ORG anonymous preference writes now take their realm's Chronicle shared advisory lock before the setting transaction, matching the lifecycle purger's Chronicle-before-setting order. A newly created preference gets a creation audit, and reset records the retirement and replacement creation. The existing user-facing failure path handles audit-write failures. The setting and Chronicle commits remain independent: a Chronicle commit failure after the setting commit can still leave a committed setting without its audit; authenticated actor preference changes also precede anonymous persistence. This change does not claim cross-database atomicity or solve that existing architectural limitation.

Focused recovery after the change: **3 tests, 18 assertions, 0 failures/errors/skips**. Recovery, cookie consent, option tampering and lifecycle-job regression together: **28 tests, 239 assertions, 0 failures/errors/skips**. APP/ORG actor preference and reset integration including both reset and replacement audit assertions: **4 tests, 68 assertions, 0 failures/errors/skips**. `bin/rubocop` for the concern and two changed test files: **3 files, no offenses**. These tests used PostgreSQL with `COVERAGE=false`; full-suite and coverage results after this change remain unverified.

### Full regression and concurrency cleanup

After restoring APP/ORG preference creation and reset audits, the full Rails run with coverage disabled completed **7,646 tests, 51,229 assertions, 0 failures, 1 error, 0 skips**. The error was in `test/concurrency/app_org_preference_write_serialization_test.rb`: its nontransactional cleanup attempted to destroy test-created preferences while their newly created audit rows still existed, triggering the intended dependent restriction. The test cleanup now deletes only audit subjects matching the IDs created by that test before destroying those preferences. No production deletion behavior changed. The corrected concurrency test passed **1 test, 22 assertions**, and its RuboCop check passed. The full suite has not yet been rerun after the cleanup correction.

### Full regression with isolated coverage output

`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=true RUBYOPT=-r/home/global/workspace/tmp/original-consistency/simplecov-isolated-output.rb bin/rails test` ran **7,646 tests, 51,244 assertions, 0 failures, 0 errors, 0 skips**. The exit status was **2**, because SimpleCov failed its configured minimums: **line 86.04% (minimum 98%), branch 57.10% (minimum 93%), method 76.63% (minimum 97%)**. The preloader only changed the report directory to `tmp/original-consistency/coverage-full` to preserve the existing `coverage/` artifacts. That isolated directory had no previous `.last_run.json`, so the maximum-drop comparisons against the existing local baseline were not performed. The coverage threshold gate is not passing; the full test assertions did pass.

`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency` was rerun after the full suite and exited **1**, reporting exactly one failure line: `UniqueIndexChecker` for `OperatorChronicle` expression index `uniq_operator_chronicles_sign_flow_halted`. No Solid Queue warning line appeared. The expression constraint and its custom application validation remain covered by the previously recorded PostgreSQL/model tests; the checker does not recognize that custom validator. This result is not a warning-free checker run.

For the same isolated full-suite coverage run, line coverage was **387/408 (94.85%)** for `PreferenceWriteBoundary`, **22/24 (91.67%)** for `CspViolationReport`, and **45/45 (100%)** for `OperatorChronicle`. The CSP concern's uncovered `super` branch applies to non-`create` actions; its current concrete report controllers expose only `create`. These file-level measurements do not satisfy or replace the failed repository-wide coverage gates.

### Read-only test database orphan scan for the additional 98 foreign keys

Ran `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails runner tmp/original-consistency/check_test_fk_orphans.rb`. The script requires a `test_` database name, starts a read-only transaction per writer, looks up each exact table and FK name from the 98-constraint fresh-build inventory, and counts orphan rows with the constraint's SIMPLE or FULL null-matching semantics. It reads aggregate counts only and rolls the transactions back; it does not validate or alter any constraint. All **98** named constraints were found and the summed orphan count was **0** in the current test databases. Validation states were: APP setting 5/5 validated, ORG setting 9/9 validated, APP signal 0/1 validated, ORG signal 0/1 validated, Chronicle 19/19 validated, and Occurrence 63/63 validated. These are the existing test database states, not the fresh-migration-built state (where all 98 were NOT VALID), and say nothing about production or shared databases. No user authorization to execute the proposed validation migrations is inferred from this read-only scan.

### Halt audit JSON key validation and remaining uniqueness gap

For `SIGN_FLOW_HALTED`, the existing PostgreSQL CHECK requires the two top-level correlation keys. Before this change the Rails model accepted missing keys and the database rejected the later insert. The strengthened test was Red (**4 tests, 1 failure**). The model now rejects missing keys before persistence, and the tests retain direct database CHECK assertions using validation bypass. Tests cover missing keys, each key separately, nested-only keys, array presence, JSON null values, other events, duplicate identities and writer-role reads. The focused audit regression passed **21 tests, 129 assertions, 0 failures/errors/skips**; RuboCop passed for the three changed model/test files.

This change mirrors the existing CHECK rather than claiming a stronger invariant: PostgreSQL `jsonb ?` also accepts an array containing the two key strings, and an object with either value JSON null passes the CHECK. In either case `->>` can be SQL NULL, and PostgreSQL's unique index permits multiple such identities. The retained audit's claimed exactly-once invariant is therefore not guaranteed for these forms. A read-only aggregate query of the current test Chronicle database found **0** rows for this event; it establishes nothing about existing production or other databases. Correcting the database contract needs an explicitly reviewed handling of existing audit rows and types, plus a migration and bypass tests; none has been applied. The latest `database_consistency` execution still exited 1 with the same single OperatorChronicle expression-index finding and no Solid Queue finding. The full test suite and coverage numbers recorded above predate this final model change.

After the halt-key model change, `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test` passed: **7,647 tests, 51,246 assertions, 0 failures, 0 errors, 0 skips**. Coverage was disabled in this run; the preceding isolated full-suite coverage figures predate this change. The reviewable schema-contract investigation is `specs/governance-database-consistency/halt-audit-identity-gap.md`. A fresh check still found `.github` mounted read-only and the prepared workflow patch applicable in check mode only.

The subsequent full Rails regression after the contact fail-closed and CSRF invariant changes passed **7,649 tests, 51,257 assertions, 0 failures/errors/skips** with `COVERAGE=false`; see `evidence/2026-11-12-remove-non-governance-databases-R4D8.md`. The isolated full-suite coverage result remains the earlier 86.04% line, 57.10% branch and 76.63% method result and predates these final changes.

The latest post-change static gates all exited 0: full `bin/rubocop` (2,919 files), `bundle exec erb_lint --lint-all` (1,203 files), `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` (no warnings), and `bun run check`. ERB lint emitted a Ruby parser/runtime version warning but found no errors. These results do not change the failed coverage gate or the outstanding expression-index checker finding.

The checker was rerun after the contact-boundary changes with `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency`; it exited 1 with the same single KEEP finding for the `OperatorChronicle` expression index. There were no Solid Queue finding lines. The `.github` mount remained read-only on recheck, and the prepared patch still passed `git apply --check` without being applied.

## Final expression-index consistency recheck

The unconfigured checker originally reported one real KEEP finding: `OperatorChronicle`'s existing PostgreSQL unique expression index was not matched to the custom model validation. No configuration exclusion, checker disablement, model exclusion or database change was introduced. Added `JsonbTextUniquenessValidator`, which queries PostgreSQL's same `->>` text expressions and event predicate on the writing role; the unique index remains authoritative under concurrency. Added bidirectional generic checker support in the ignored `vendor/fork/database_consistency` checkout and captured the complete fork diff, including tests, in `patches/database-consistency-postgresql-validation-semantics.patch`. The checker requires the exact expression keys and predicate and rejects unsupported conditional guards, collations, operator classes, invalid indexes and NULLS NOT DISTINCT semantics. The inverse missing-index checker also recognizes the validator.

TDD began with the standard checker finding and new exact-match, mismatch and inverse-direction checker examples failing against the unmodified checker. They now pass with the fork's full RSpec suite: **478 examples, 0 failures**. PostgreSQL model/index regression passed **22 tests, 88 assertions, 0 failures/errors/skips**, including duplicate rejection with validation bypass, distinct generations, other event types, NULL expression behavior, and SQL-injection-shaped identity text. The model validation explicitly forces the writing role. Brakeman first identified the validator's interpolated SQL; the query was changed to Arel JSON operators with bound JSON input, after which Brakeman reported **0 security warnings**. Focused RuboCop passed for the three application/test files. `git apply --reverse --check -p1 patches/database-consistency-postgresql-validation-semantics.patch` passed against the current ignored fork checkout.

On the final code, `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency` exited **0** and emitted no finding lines (its only output was `No configuration files were provided`). This is **0 reported KEEP findings**. No Solid Queue finding was emitted; Queue remains excluded from the evaluation. A prior full Rails run during the validator edit returned one failure, but its unredirected PTY output did not retain the failing test detail. Repeating with the same seed after the final query implementation completed **7,649 tests, 51,263 assertions, 0 failures, 0 errors, 0 skips**. The focused PostgreSQL regression and final full run both pass; the earlier isolated 22-test attempt that collided with the full-suite database lock was rerun successfully after the full suite ended.

This checker result does not close the separately recorded Chronicle JSON-null/array identity gap: the existing CHECK and unique index permit duplicate rows when either extracted key is SQL NULL. No schema contract change for that issue has been approved or applied. The proposed validation of the additional **98 existing NOT VALID foreign keys** also remains unimplemented pending its separate approval; the prior approval covered only 42 other constraints. Production/shared database contents were not inspected or changed. The final worktree still has extensive uncommitted changes; full HEAD for this evidence is `43db4906742db2fb13b238c9ccde378e4e1583b4`.

## Latest verification after removal and coverage continuation

Reran the unconfigured checker against the latest worktree with
`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency`: exit
**0**, output `No configuration files were provided`, with **0 reported KEEP findings**. No
Solid Queue finding was reported or evaluated.

The coverage-disabled full suite passed **7,657 tests, 51,376 assertions, 0 failures, 0 errors,
0 skips**. The coverage-enabled full suite ran the same tests successfully, then SimpleCov exited
2 on unchanged minimums: line **86.08%** (30,453/35,376; minimum 98%), branch **57.16%**
(3,676/6,431; minimum 93%) and method **77.03%** (4,518/5,865; minimum 97%). The independent
Vitest coverage run passed **68 files / 696 tests** at 100% statements, 99.7% branches (1,021/1,024),
100% functions and 100% lines.

The additional 98 foreign keys remain unvalidated in fresh-migration output pending separate scoped
approval. The Chronicle event-18 JSON identity gap also remains an open contract requiring current
owner/type decisions and PostgreSQL bypass/migration tests. Neither is counted as a checker finding,
and neither was hidden or modified in this verification. Production/shared databases were not
inspected or changed. Full HEAD remains `43db4906742db2fb13b238c9ccde378e4e1583b4`; extensive
uncommitted work remains present.
