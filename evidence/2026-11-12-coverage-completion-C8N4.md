# Coverage completion checkpoint

HEAD: `43db4906742db2fb13b238c9ccde378e4e1583b4`.

The working tree contained extensive pre-existing uncommitted changes, including the ongoing Rails
split, recovery tests and new Vitest files. No reset, stash, commit or unrelated reformat was done.
Coverage status remains **in progress**; this checkpoint does not claim complete public/protected
Minitest method coverage.

## Verified behavior

- The Avatar authority client operation tests first failed with two failures in 65 assertions. One
  test expectation was corrected to include the protocol's absent selection fields. The remaining
  failure showed that `switch_context` merged the previously selected organization over the new
  requested selection. The request now supplies the caller's target organization while retaining the
  current persona. The focused adapter regression passed **6 tests / 80 assertions**. A combined
  related run passed **28 tests / 214 assertions**, with no failures, errors or skips.
- Added public-boundary cases for request-region normalization, the retired OIDC endpoint failures,
  Base self-RP identifiers and expired-token session-ID extraction. A previous full Rails test run
  passed **7,657 tests / 51,376 assertions / 0 failures / 0 errors / 0 skips**:

  ```text
  env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test
  ```

- The prior coverage-enabled full Rails result below has been superseded by the latest refresh at
  the end of this evidence file.

- Final Vitest coverage command passed **68 files / 696 tests** with **100% statements, 99.7%
  branches (1,021/1,024), 100% functions and 100% lines**, above the repository's unchanged 99%
  thresholds:

  ```text
  bun run test:coverage --coverage.reportsDirectory=tmp/coverage-task/vitest-final-after-lint
  ```

  The three uncovered branches are nullish fallbacks at `AdminConfirmation.tsx` lines 139 and 154
  and `src/lib/theme.ts` line 88. The AdminConfirmation inputs are initialized and preserved as
  strings by the current typed component contract; no source exclusion or threshold change was made.

## Final static checks

- `bin/rubocop`: **2,922 files**, no offenses.
- `bundle exec erb_lint --lint-all`: **1,203 files**, no errors. The parser emitted its existing
  Ruby 3.3 grammar / Ruby 4.0.9 runtime compatibility warning.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: **0 errors, 0 security
  warnings**.
- `bun run check`: exit 0 after formatting and typing fixes to moved WebAuthn, Turnstile,
  preference, selector and surface-layout tests. Test mocks now use typed request signatures and
  visit lifecycle helpers; no lint rule or check was suppressed.

## Remaining work

The Vitest acceptance and full Minitest behavioral suite pass. The Minitest coverage gates remain
below their configured minimums, and the current public/protected method inventory has not been
fully reconciled with runtime reachability or classified. The 2026-11-06 inventory is stale and is
not used as current evidence. No reflection or direct private-method calls were added. This coverage
goal remains incomplete.

A fresh runtime scan via
`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails runner tmp/coverage-task/list_public_methods.rb`
found 4,377 owner/method rows. The latest source path, definition-line and terminal method-name join
maps 3,408 to reached methods, 752 uncovered rows over 581 source locations, and 217 rows to no
single instrumented method entry. That join is preliminary: generated aliases and concern owner
labels account for unmatched rows, so it is not presented as a complete public-method audit. Source
review confirms `FlowSignIn`/`FlowSignUp` have no app includes, `OpaqueAdmissionStore` has no app
caller, and the Avatar owner APIs fail closed before action until Access's API exists; the remaining
locations have not all been classified.

## Latest public-method audit batch

The preceding full-run SimpleCov report had not reached `CoreRpBridge#actor`, `#subject` or
`#core?`. Added model-level behavior cases for the live `CoreAppClientBridge` and
`CoreOrgOperatorBridge`: they exercise default/legacy normalization, external RP identity
preservation, actor and subject lookup, and Core classification. The focused run passed **6 tests /
49 assertions / 0 failures / 0 errors / 0 skips**:

```text
env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test test/models/core_app_client_bridge_test.rb test/models/core_org_operator_bridge_test.rb
```

`bin/rubocop test/models/core_app_client_bridge_test.rb test/models/core_org_operator_bridge_test.rb`
passed with no offenses. A focused SimpleCov run covered **36/36 source lines** in
`app/models/concerns/core_rp_bridge.rb`. Its method report covered the concern's authored methods;
the six reported misses are generated `class_attribute` predicate readers and an unused generated
foreign-key reader. As expected, this two-file run exited 2 because it applies the unchanged global
coverage thresholds to a partial suite (5.13% lines, 2.03% branches and 5.13% methods overall). It
does not replace a full-suite result.

Caller review also confirmed that `AuthAdmissionBinding` is not included by an application class;
`SignFlow` reads only its duration constant. `RefreshTokenShared` has no application include site or
caller. `FlowSignIn`, `FlowSignUp` and `OpaqueAdmissionStore` remain without application consumers.
The Step-Up grant/result decode APIs and result issuer have no current application call site. Those
unreached APIs are recorded for reachability review; no test-only caller or reflective call was
added. A source search also found no application includer or caller of `OidcConnectionRecord`; its
ownership/deletion disposition remains open. The coverage spec now records these dispositions.

## Latest full Minitest and inventory refresh

Command:

```text
env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=true RUBYOPT=-r/home/global/workspace/tmp/coverage-task/simplecov-latest-output.rb bin/rails test
```

Minitest completed **7,668 runs / 51,426 assertions / 0 failures / 0 errors / 0 skips**. The process
exited **2** after SimpleCov enforced the existing repository-wide minima: lines **30,488/35,376
(86.18%; minimum 98%)**, branches **3,687/6,431 (57.33%; minimum 93%)**, and methods **4,534/5,865
(77.30%; minimum 97%)**. No coverage thresholds, exclusions or source ignore annotations changed.
The NanoID gem emitted its existing Ruby future-freeze warning repeatedly.

The corrected runtime public/protected inventory join yields **4,377 rows: 3,408 reached, 752
uncovered across 581 source locations, and 217 unmatched**. By visibility: public instance **3,155
(2,351 reached / 589 uncovered / 215 unmatched)**; public class **1,145 (1,009 / 134 / 2)**; and
protected instance **77 (48 / 29 / 0)**. Unmatched rows include Rails-generated helper proxies,
attribute readers/writers, dynamic methods, aliases and methods whose runtime owner differs from
their source-level label; these are not reported as reached or uncovered until their source and
caller relationship is reconciled. `BrowserRpAuthentication` is the largest named uncovered group
(29 rows), followed by `FlowSignUp` (23), `FlowSignIn` (21), and `AuthAdmissionBinding` (18). All
four source-level public/protected `CoreRpBridge` methods are reached. All six public
`AuthMethodGuard` class methods are reached; its focused tests passed **5 tests / 9 assertions / 0
failures / 0 errors / 0 skips**. The full test process includes those tests. This remains an
incomplete reachability audit; no full Minitest coverage or AC-3 completion claim is made.

Two new Base APP integration tests exercise actual routes. The foreign-Origin request is rejected
with no Preference or Chronicle write and reaches
`BrowserRpAuthentication#browser_rp_trusted_origins`; the malformed RP cookie request to JSON Home
returns 401 and expires both RP cookies, reaching
`BrowserRpAuthentication#render_browser_rp_invalid_credentials!`. Focused runs passed **1 test / 7
assertions** and **1 test / 13 assertions**; targeted RuboCop passed for both files. The first
origin test attempt failed in test setup because `assert_no_difference` was given an array; separate
count assertions corrected it. The full Minitest run above includes both new cases. The
public/protected reachability audit remains incomplete.

## Latest Minitest refresh after membership-directory fail-closed coverage

Full HEAD: `43db4906742db2fb13b238c9ccde378e4e1583b4`. The worktree already contained extensive
uncommitted changes; they were preserved. No coverage threshold, exclusion, or source ignore was
changed.

Command:

```text
env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=true RUBYOPT=-r/home/global/workspace/tmp/coverage-task/simplecov-latest-output.rb bin/rails test
```

Minitest completed **7,669 runs / 51,530 assertions / 0 failures / 0 errors / 0 skips**. The process
then exited **2** because SimpleCov enforced the existing repository minima: lines **30,479/35,376
(86.15%; minimum 98%)**, branches **3,685/6,431 (57.30%; minimum 93%)**, and methods **4,534/5,865
(77.30%; minimum 97%)**. The repeated NanoID future-freeze warning remains from the installed
dependency.

A new HTTP integration test exercises all seven APP and all seven ORG membership-directory routes
while the Access authority API is unavailable. Each request receives an explicit 503 problem
response with `no-store`, no redirect and no fabricated empty account list. The focused test passed
**1 test / 112 assertions / 0 failures / 0 errors / 0 skips**; targeted RuboCop passed. The external
client assertion verifier is stubbed at that boundary; the Access lookup and fail-closed response
are the real application path.

The runtime public/protected inventory was refreshed against the latest SimpleCov report: **4,377
rows, 3,408 reached, 752 uncovered across 581 source locations, 217 unmatched**. Visibility counts
remain public instance **3,155 (2,351 reached / 589 uncovered / 215 unmatched)**, public class
**1,145 (1,009 / 134 / 2)** and protected instance **77 (48 / 29 / 0)**. The reachability
classification is incomplete. The latest run therefore confirms green behavioral assertions but does
not pass the repository SimpleCov gates or complete the public/protected audit.
