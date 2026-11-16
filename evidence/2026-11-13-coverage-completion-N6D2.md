# Coverage Completion — Latest Minitest Recheck

Date: 2026-11-13

Repository: `umaxica-apps-cosmos-governance`

HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

Before this record, `git status --porcelain=v1` reported 750 changed or untracked paths. The
combined worktree was already heavily modified. No commit, push, CI change or coverage-threshold
change was made.

## Full test and coverage result

The current full Minitest suite ran **7,513 tests / 49,705 assertions**, with zero failures, errors
or skips. The process exited 2 only because unchanged SimpleCov minimums were not met:

- Line: **89.16%** (29,246 / 32,800; minimum 98%).
- Branch: **60.70%** (3,496 / 5,759; minimum 93%).
- Method: **83.17%** (4,321 / 5,195; minimum 97%).

Command:

```text
RUBYOPT=-W0 COVERAGE=true POSTGRESQL_TEST_PREPARE_DATABASES=<isolated test writer list> RAILS_ENV=test bin/rails test
```

The same worktree's separate non-coverage full test run passed **7,513 / 49,702**. The three
assertion difference between runs is unexplained; both runs had the same test count and zero test
failures. The SimpleCov denominators changed from the earlier coverage run as the combined
source/test tree changed; percentage deltas are not a direct comparison.

The coverage run printed `AccessOpDataUnavailableError` thread reports from
`test/concurrency/enforcement_reconciliation_end_race_test.rb` and
`test/concurrency/administrative_access_lock_clock_test.rb`. Those tests assert the same public
refusal using `worker.value`; Minitest reported no failure, error or skip. The reports were not
suppressed.

The latest frontend coverage result remains the previously recorded 59 files / 588 tests at 100%
statements, functions and lines, and 100% branches. It was not rerun because no frontend source
changed after that run.

## Public/protected method inventory

The current runtime inventory was regenerated with:

```text
RUBYOPT=-W0 RAILS_ENV=test bin/rails runner tmp/coverage_method_inventory.rb > tmp/coverage-method-inventory-2026-11-13-current.json
```

Its 2,716 rows were joined to the current SimpleCov method data by source, line, owner and method,
normalizing Active Record singleton-class owner labels. The resulting counts are:

| Visibility         |     Total |   Reached | Uncovered | Unmatched |
| ------------------ | --------: | --------: | --------: | --------: |
| Public instance    |     1,625 |     1,261 |       196 |       168 |
| Public class       |     1,015 |       964 |        40 |        11 |
| Protected instance |        76 |        49 |        27 |         0 |
| **Total**          | **2,716** | **2,274** |   **263** |   **179** |

The 263 uncovered rows span 234 source locations. The complete temporary list is
`tmp/coverage-public-protected-uncovered-2026-11-13-normalized.txt`. It is ignored tooling output,
not a tracked artifact. The previous inventory had 2,726 rows, 277 uncovered and 170 unmatched;
removed legacy methods and later test additions changed the inventory, so method-level attribution
is required before treating the counts as a direct progress comparison.

## Work since the prior coverage evidence

- A static regression test for the unused `AccessPolicy` declaration path failed against the old
  `BrowserRpAuthentication` DSL. The unused branch, policy class and policy-only test were removed;
  the focused authentication tests then passed **22 tests / 4,275 assertions**. This is the Red /
  Green evidence for that removal.
- Added public-path coverage for APP and ORG passkey index requests and the Withdrawal re-entry
  page. Their focused integrations passed **5 / 40** and **2 / 40**, respectively.
- Added value tests for actor anonymity, authentication-context string conversion, the WebAuthn
  public registry entrypoints and OIDC client assertion results; the focused value run passed **12 /
  54**.
- Moved `BannerModel` declarations from its inclusion hook into the two concrete models. Existing
  model/query behavior tests passed **15 / 44** before and after the move; this structure-only
  refactor had no intentionally failing behavior test.
- The latest combined focused recheck passed **20 / 4,321** and included the authentication,
  passkey, Withdrawal and static-invariant tests. The latest full suite is recorded above.

No reflection, synthetic private-method invocation, test-only application branch, skipped test or
weakened assertion was added. No database schema or coverage setting changed as part of this
coverage recheck.

## Acceptance status

- AC-1 remains met on the latest tested frontend source; its coverage thresholds were unchanged.
- AC-2's Rails tests pass, but the existing line, branch and method coverage minimums remain unmet.
- **AC-3 remains open:** 263 mapped public/protected rows are uncovered and 179 rows do not map
  one-to-one to SimpleCov methods. A current caller/reachability disposition has not been completed
  for every row.
- The specification remains `implementing`; see
  [`specs/test-coverage-completion/spec.md`](../specs/test-coverage-completion/spec.md).
