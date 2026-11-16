# Coverage completion pass

Date: 2026-11-13

HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71` (unchanged; no commit or push).

The worktree already had **735 modified/untracked paths** when this pass continued; it had **738**
at the end. Existing work was preserved. `.github/workflows/ci.yml` was already modified in the
worktree when checked and was not edited in this pass. No CI configuration or database schema was
changed.

## Changes

- Added focused coverage for adult-content preference gates and defaults, Apple notification retry
  and terminal states, avatar ownership history and grant boundaries, TOTP failure/revocation
  transitions, actor context helpers, registration catalog readonly behavior, lifecycle predicates,
  switcher authority reads, browser session public IDs, avatar image cache keys, and selectable Base
  APP preference writes.
- Fixed `Actor::StepUp.null` to reference `Actor::StepUp::NULL`. Its new test first failed with
  `NameError: uninitialized constant Actor::NULL`; after the fix, the focused actor/config/ceremony
  group passed **63 tests / 264 assertions**.
- Added HTTP tests showing the Base APP Secret index and the Base ORG Support client-detail and
  revocation-history pages fail closed with 503, do not redirect, and do not expose the target's
  public ID when the owner context is unavailable. The Support session-revocation test file passed
  **4 tests / 21 assertions**. The preference screen integration test passed **3 / 11**; the Secret
  boundary test passed **1 / 4**.

## Verification

- `bun run test:coverage` — **59 files / 588 tests passed**; statements **100% (1,072/1,072)**,
  branches **100% (824/824)**, functions **100% (360/360)**, lines **100% (1,045/1,045)**.
- `COVERAGE=true bin/rails test` with
  `POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_com_setting_db,test_org_setting_db,test_app_signal_db,test_org_signal_db,test_avatar_db,test_chronicle_db,test_occurrence_db,test_queue_db,test_storage_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db`
  — **7,512 tests / 49,713 assertions; 0 failures, 0 errors, 0 skips**. The command exited 2 only
  because existing SimpleCov minimums were not met: line **89.05% (29,238/32,832; minimum 98%)**,
  branch **60.46% (3,485/5,764; minimum 93%)**, method **82.51% (4,295/5,205; minimum 97%)**.
  Thresholds and exclusions were unchanged.
- Refreshed Ruby public/protected runtime inventory: **2,726 rows**, **2,279 reached**, **277
  uncovered**, **170 unmatched** to a one-to-one source-level SimpleCov method. The uncovered rows
  span **245 source locations**. Breakdown: public instance 1,632 (1,260 reached / 204 uncovered /
  168 unmatched); public class 1,017 (970 / 45 / 2); protected instance 77 (49 / 28 / 0).
- `bundle exec rubocop` on the 21 touched Ruby files — **no offenses**.
- `git diff --check` on touched implementation, test, spec, and evidence paths — clean.

## Remaining

The Vitest coverage acceptance is met. The complete Minitest suite passes, but its existing
SimpleCov gate still fails at the recorded thresholds. Some uncovered controller action bodies are
blocked by the Access owner API before the action runs; related fail-closed request tests preserve
the explicit unavailable response. Other uncovered entries include helpers with no current product
caller, configuration/environment construction, and owner paths awaiting their service boundary. The
refreshed inventory has not received a per-method reachability disposition for all 277 uncovered
rows, so AC-3 remains open and the specification remains `implementing`.

The latest measurements and current AC status are recorded in
[`specs/test-coverage-completion/spec.md`](../specs/test-coverage-completion/spec.md).
