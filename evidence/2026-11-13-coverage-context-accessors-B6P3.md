# Public Request-Context Coverage Follow-Up

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had 1,103 changed or untracked paths before this work sequence and 1,114 before
this coverage record. Existing uncommitted changes were preserved. The pre-existing two-line
`public` section change in `app/controllers/concerns/preference_global.rb` was present before this
coverage item and was not removed. No commit, push, CI, credentials, or schema source change was
made.

## Change and test disposition

The preceding coverage inventory identified eleven private `PreferenceGlobal#request_context_*`
accessors with zero coverage. A repository-wide search found only their definitions, so removal was
attempted. The existing
`ExplicitContextAccessorsTest#test_context_accessors_remain_private_zero_argument_methods_on_consumers_and_subclasses`
failed. That test records an intentional private accessor contract, so neither the methods nor the
test were weakened.

The methods were restored, and `PreferenceGlobal#request_context` now routes each of the twelve
fixed `RequestContextContract.public_keys` through its corresponding accessor. Unknown keys raise an
explicit `ArgumentError`. This keeps the accessor contract in active production use through the
public context builder. No dynamic dispatch, direct private-method calls, or test-only code was
introduced. Existing tests already assert the full public context result, so no test file changed.

The focused `ExplicitContextAccessorsTest`, preference-context integration tests, and RI routing
guard passed **64 runs / 867 assertions / 0 failures / 0 errors / 0 skips**. Targeted RuboCop passed
for the changed concern (**1 file, no offenses**), and `git diff --check` passed.

## Coverage results

| Check               |            Before this pass |                                  After this pass |    Minimum |
| ------------------- | --------------------------: | -----------------------------------------------: | ---------: |
| Line coverage       |    90.51% (30,120 / 33,275) |                         90.55% (30,143 / 33,288) |        98% |
| Branch coverage     |      62.24% (3,511 / 5,641) |                           62.31% (3,523 / 5,654) |        93% |
| Method coverage     |      85.89% (4,348 / 5,062) |                           86.13% (4,360 / 5,062) |        97% |
| Full Rails Minitest | 7,516 / 50,260 / 0 failures | 7,516 / 50,265 / 0 failures / 0 errors / 0 skips | 0 failures |

The coverage-enabled full command was `bin/rails test` with the repository's configured coverage
switch and test database safety scope. It completed all **7,516 tests / 50,265 assertions** with
zero failures, errors, or skips. The process exited **2** after SimpleCov enforced the unchanged
minimums. Coverage reports remain generated artifacts and were not checked in.

One intermediate coverage-enabled run reported **17 failures** after the private-accessor removal
had already been reverted. The next coverage-enabled full run passed with zero failures, as did the
coverage-disabled full run (**7,516 / 50,259 / 0 failures**). The intermediate failures did not
reproduce. The attempted deletion run itself reported **1 failure** in the explicit accessor
contract and was reverted; its temporary coverage numbers are not counted as progress.

## Remaining limits

The prior inventory still has **115 exact public/protected misses**, with owner-unavailable paths,
accepted policy helpers without current callers, and maintenance/configuration entrypoints
dispositioned in
[`2026-11-13-coverage-current-resumption-Z9P4.md`](2026-11-13-coverage-current-resumption-Z9P4.md).
The aggregate minima remain unmet; this pass is incremental evidence, not acceptance closure. The
full test setup used the current verified writer list; a first attempt with the inherited stale
selection stopped at the database safety guard before migrations or tests ran. The successful
attempts derived the writer list from the active Rails test configuration without printing its
values.
