# Coverage revalidation after ceremony cleanup

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had 1,072 changed or untracked paths before this evidence was added. It contains
substantial prior work. This pass changed no application code, tests, CI, coverage thresholds,
exclusions, credentials, or database schema. No commit or push was made.

## Current verification

| Check                                      | Result                                                                                                                                                                                       |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bun run test:coverage`                    | Passed: **59 files / 588 tests**; statements **100% (1,072/1,072)**, branches **100% (824/824)**, functions **100% (360/360)**, lines **100% (1,045/1,045)**.                                |
| Full Rails suite after ceremony cleanup    | **7,492 tests / 50,156 assertions / 0 failures / 0 errors / 0 skips**, recorded in `2026-11-13-remove-unreachable-ceremony-code-V9Q2.md`.                                                    |
| Full Rails coverage after ceremony cleanup | All tests passed; SimpleCov exited 2 at **90.37% line (30,098/33,304)**, **62.03% branch (3,501/5,644)**, and **85.57% method (4,338/5,069)**, below the unchanged 98% / 93% / 97% minimums. |

## Refreshed public/protected inventory

The Rails runtime inventory was regenerated after cleanup using the explicit current test-writer
list. The full test coverage resultset remained available after the Vitest run. Its 17 resultsets
were joined by source location with the installed `SimpleCov::Combine::MethodsCombiner`, then
matched against current source paths, method names and start lines.

| Visibility         | Total rows | Exact hits | Uncovered | No one-to-one location | Same-line name mismatch |
| ------------------ | ---------: | ---------: | --------: | ---------------------: | ----------------------: |
| Public instance    |      1,603 |      1,344 |       105 |                    135 |                      19 |
| Public class       |        912 |        890 |        20 |                      0 |                       2 |
| Protected instance |         61 |         49 |        12 |                      0 |                       0 |
| **Total**          |  **2,576** |  **2,283** |   **137** |                **135** |                  **21** |

The 137 uncovered method identities match the prior 137 by source path and method name; none is new
after the cleanup. The existing reachability evidence classifies them as Access-owned action bodies
stopped by explicit fail-closed boundaries, maintenance/configuration entrypoints, or methods with
no current application caller. The 135 unmatched rows are generated methods without one-to-one
coverage locations, and the 21 name mismatches are same-line aliases. No reflection or synthetic
test path was used.

## Status

- Vitest's existing 99% gates pass at 100% for all four metrics on the current frontend tree.
- The full Rails tests pass, but the SimpleCov gates remain below minimums.
- Public/protected rows were refreshed; no new uncovered identity appeared. The two contract
  discrepancies and the previously classified unreachable rows remain open as recorded in the
  reachability evidence.
- This revalidation adds no Red/Green cycle because it made no behavior or test change. Prior
  behavior changes and their Red/Green results remain in the linked unit evidence.
