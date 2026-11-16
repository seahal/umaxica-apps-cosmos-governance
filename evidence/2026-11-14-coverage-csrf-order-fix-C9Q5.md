# CSRF test order and coverage revalidation

## Context

- Spec: [`specs/test-coverage-completion/spec.md`](../specs/test-coverage-completion/spec.md)
- Repository HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`
- The worktree contained 1,267 staged, unstaged, and untracked paths during this pass. Existing work
  was preserved. No commit or push was made.

## Change

`test/integration/routes/neutral_rp_entry_contract_test.rb` now sets CSRF protection on
`ActionController::Base`, the shared Rails class attribute, then restores the configured default.
The previous assignment to `Base::App::ApplicationController` created a subclass-local value and
left later controllers with CSRF disabled after the test. No application code, test setup, coverage
threshold, exclusion, or ignore annotation changed.

## Red and Green

| Command                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Result                                                                                                                          |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `env -u POSTGRESQL_TEST_PREPARE_DATABASES -u COVERAGE PARALLEL_WORKERS=1 bin/rails test test/integration/routes/neutral_rp_entry_contract_test.rb:54 test/controllers/base/app/api/v0/preferences/theme_controller_test.rb:95` before the correction                                                                                                                                                                                                                                                                                                                         | Red: **2 runs / 5 assertions / 1 failure**. The theme request failed because the earlier test shadowed the shared CSRF setting. |
| Same focused command after the correction                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Green: **2 runs / 9 assertions / 0 failures / 0 errors / 0 skips**.                                                             |
| `env -u POSTGRESQL_TEST_PREPARE_DATABASES -u COVERAGE PARALLEL_WORKERS=1 bin/rails test test/integration/routes/neutral_rp_entry_contract_test.rb test/integration/preference_web_csrf_test.rb test/integration/preference_browser_api_contract_test.rb test/integration/csrf_notification_emission_test.rb test/integration/jump_rt_return_verification_test.rb test/controllers/base/app/api/v0/preferences/theme_controller_test.rb test/controllers/base/app/api/v0/preferences/web_pushes_controller_test.rb test/controllers/csp_violation_reports_controller_test.rb` | **84 runs / 1,511 assertions / 0 failures / 0 errors / 0 skips**.                                                               |
| `bin/rubocop test/integration/routes/neutral_rp_entry_contract_test.rb`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Exit 0; no offenses.                                                                                                            |

## Aggregate verification

- `env -u POSTGRESQL_TEST_PREPARE_DATABASES COVERAGE=true PARALLEL_WORKERS=1 bin/rails test` passed
  **7,603 runs / 51,027 assertions / 0 failures / 0 errors / 0 skips**. SimpleCov returned exit 2
  for the unchanged minimums: **90.73% lines (31,261/34,454), 62.14% branches (3,636/5,851), and
  88.28% methods (4,670/5,290)** against **98% / 93% / 97%**. An output-collection wrapper also
  emitted a Ruby `NameError` after the Rails command while reading its result variable; the native
  Rails aggregate and SimpleCov output were present and are the source of the counts above.
- `bun run test:coverage` passed **60 files / 594 tests** at **100% statements (1,081/1,081),
  branches (838/838), functions (362/362), and lines (1,054/1,054)**. No JavaScript or TypeScript
  changed in this pass.
- The refreshed public/protected inventory joined **2,618 rows**: **2,352 reached, 104 exact misses,
  140 without one-to-one SimpleCov locations, and 22 same-line/name mismatches**. The remaining
  exact misses are owner-data paths that stop at the unavailable Access boundary, shared
  verification helpers not reached by current requests, IAM operations behind that boundary, and
  methods retained under the current authorization design. Tests were not made to bypass those
  boundaries.
- The full Rails run changed migration-owned validation state in disposable APP Setting, ORG
  Setting, and Occurrence test databases. After confirming zero active sessions, each database was
  rebuilt individually. Final receipts: APP Setting **17 migrations / 5 unvalidated foreign keys**;
  ORG Setting **17 / 9**; Occurrence **118 / 63**. Each had zero unvalidated CHECK constraints. APP
  Signal and ORG Signal each remained at **7 migrations / 1 unvalidated foreign key**; Chronicle
  remained **34 migrations / 0**. Queue and non-test databases were not operated on.
- After restoration, `RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` exited 0
  with no findings. This is separate from the Minitest coverage gate.

## Remaining acceptance limits

Vitest coverage passes its configured thresholds. Minitest behavior passed, but all three existing
SimpleCov minimums remain unmet. Exact public/protected misses include controller actions whose
before-actions return explicit unavailability while Access-owned data APIs are absent; executing
their action bodies would require crossing that authorization boundary. AC-2 and AC-3 remain open.
