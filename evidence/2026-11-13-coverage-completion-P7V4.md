# Vitest and Minitest Coverage Completion — Latest Recheck

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree was already heavily modified. `git status --short` reported 1,004 paths before
this evidence and specification update. Results describe the combined dirty tree; they cannot all be
attributed to this coverage work. No commit, push or deployment was made. No CI, credentials or
database schema change was made for this coverage recheck.

## Work in this recheck

- Removed `BannerModel#actor`, a default `nil` method overridden in both actual includers, and the
  empty `PromotionalEmailUnsubscribeActions#edit`, overridden by both concrete email controllers.
  Their active concrete model/controller paths and tests remain.
- Added a model test for `EnforcementRecoveryCeremonyRecordable#revoke!`: an active recovery token
  becomes terminally revoked, has `revoked_at`, remains unconsumed, and can no longer authenticate.
  This security lifecycle method remains in production.
- Added explicit unavailable-response coverage for 52 APP/ORG Access-authority API method/path pairs
  in `test/integration/base_access_authority_api_unavailable_test.rb`. Together with existing
  membership, switcher, dashboard identity, IAM grant-create and capability tests, the API
  entrypoints return explicit unavailable responses while Access authority is absent.
- Re-ran public/protected method reachability using the current Rails runtime and the 17 raw
  parallel SimpleCov resultsets combined through the installed
  `SimpleCov::Combine::MethodsCombiner`. Temporary row-level outputs are in ignored
  `tmp/coverage-task/public-protected-joined-current.json` and companion lists.

No test-only production branch, reflection, direct private-method call, weakened assertion, coverage
exclusion or threshold change was added. The new tests verify existing fail-closed contracts; no
production behavior change was needed to obtain their results. No separate RED run was made for the
deletion of the two shadowed methods because their concrete overrides were preserved.

## Verification

| Command                                                                                                            | Result                                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bun run test:coverage`                                                                                            | Passed: 59 files, 588 tests; statements 100% (1,072/1,072), branches 100% (824/824), functions 100% (360/360), lines 100% (1,045/1,045).                                                                                                                                          |
| `COVERAGE=true RUBYOPT=-W0 POSTGRESQL_TEST_PREPARE_DATABASES=<current test writers> RAILS_ENV=test bin/rails test` | All 7,499 tests passed: 50,194 assertions, 0 failures, 0 errors, 0 skips. Process exited 2 only because existing SimpleCov thresholds remain unmet: line 90.34% (30,163/33,388; minimum 98%), branch 61.89% (3,500/5,655; minimum 93%), method 85.52% (4,356/5,093; minimum 97%). |
| `bin/rubocop`                                                                                                      | Passed: 2,817 Ruby files, no offenses.                                                                                                                                                                                                                                            |
| Focused model and unsubscribe-controller tests                                                                     | 28 tests, 94 assertions, 0 failures/errors/skips.                                                                                                                                                                                                                                 |
| Focused recovery-ceremony transition test                                                                          | 2 tests, 11 assertions, 0 failures/errors/skips.                                                                                                                                                                                                                                  |
| Focused Access-unavailable boundaries                                                                              | 9 tests, 515 assertions, 0 failures/errors/skips.                                                                                                                                                                                                                                 |
| `RAILS_ENV=test bin/rails zeitwerk:check`                                                                          | Passed: `All is good!`.                                                                                                                                                                                                                                                           |
| `git diff --check`                                                                                                 | Passed.                                                                                                                                                                                                                                                                           |
| `git diff --exit-code HEAD -- config/credentials`                                                                  | Passed; no credential paths changed.                                                                                                                                                                                                                                              |
| `RAILS_ENV=test bundle exec database_consistency`                                                                  | Exit 1 with one existing finding: `UniqueIndexChecker fail OperatorChronicle uniq_operator_chronicles_sign_flow_halted index is unique in the database but does not have a uniqueness validator`. No checker suppression/configuration was added.                                 |

The full Rails coverage command ran only against the explicit current test-writer database catalog;
it did not drop or prepare production, shared or external databases.

## Public/protected method inventory

The current runtime inventory has **2,597 rows**. Joining raw worker method tuples by SimpleCov
source identity produced **2,297 exact hits**, **144 uncovered rows**, **135 rows with no one-to-one
source method location**, and **21 rows whose source line has a hit for another runtime method**.
The uncovered rows occupy 144 source locations. By visibility:

| Visibility         | Exact hit | Uncovered | No location | Other method on same line |
| ------------------ | --------: | --------: | ----------: | ------------------------: |
| Public instance    |     1,358 |       106 |         135 |                        19 |
| Public class       |       890 |        20 |           0 |                         2 |
| Protected instance |        49 |        18 |           0 |                         0 |

The uncovered rows include public action bodies whose real routes stop at the accepted unavailable
Access-authority boundary; their HTTP requests are covered for explicit 503 behavior and no
successful or empty fallback. Other still-unclassified rows include policy helpers with no direct
product call site, generated `class_attribute` predicates, configuration/environment construction,
maintenance-only entrypoints, and models/operations with no application caller. The mapping-only
rows include generated aliases and methods sharing a source line with another instrumented method.
The full per-row caller disposition remains incomplete; no force-calls were added to manufacture
coverage.

The prior recorded T8R3 inventory had 2,657 rows, 192 uncovered, and 142 unmatched. Inventory size,
instrumentation and source/test trees changed across the heavily modified shared worktree, so those
counts are not directly comparable. The current SimpleCov aggregate remains below its configured
minimums even though all Rails tests pass.

## Acceptance status

- **AC-1 met:** the latest Vitest coverage run passes all existing thresholds at 100%.
- **AC-2 partly met:** all Rails tests pass, but the unchanged SimpleCov line, branch and method
  thresholds remain unmet.
- **AC-3 open:** 144 mapped public/protected methods remain uncovered, and the 135 unmatched and 21
  same-line rows still require full caller/reachability disposition. Access-owned APIs remain
  explicitly unavailable until Access supplies the accepted data service.
- **AC-4 open:** full row-by-row disposition and final coverage acceptance remain incomplete.

The current status of `specs/test-coverage-completion/spec.md` remains `implementing`. The
DatabaseConsistency warning remains separately tracked in
[`2026-11-13-database-consistency-final-H6Q2.md`](2026-11-13-database-consistency-final-H6Q2.md).
