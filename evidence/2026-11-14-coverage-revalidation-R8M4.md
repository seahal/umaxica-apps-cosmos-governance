# Coverage revalidation and Base RP anonymous redirect

Date: 2026-11-14  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
Full HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The worktree had 1,253 changed or untracked entries when this coverage slice resumed. Existing
changes were preserved; no commit or push occurred. The only application behavior involved was
already implemented. This slice corrected two request-test expectations and refreshed validation.

## Base RP request-test correction

`BaseSharedRpCellSelectionTest` removed the RP-local session cookie and expected the next HTML GET
to return 401 with no redirect. The established `BaseRpSignInRedirect` contract sends an
unauthenticated GET to that RP's own sign entry with 303 and `no-store`. The test failure was an
expectation mismatch, not an authorization defect. Both APP and ORG tests now assert their own
sign-entry path with `target_link_uri=/verification` and `no-store`; the unavailable Access issuance
POST remains asserted as 503.

Red/Green and related checks:

| Command                                                                               | Result                                                                                  |
| ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Before assertion correction, `test/integration/base_shared_rp_cell_selection_test.rb` | 2 runs / 8 assertions / 2 failures; both expected 401 while the controller returned 303 |
| After correction, same focused file                                                   | 2 runs / 16 assertions / 0 failures / 0 errors / 0 skips                                |
| `test/integration/cycle_close_authenticated_roots_test.rb`                            | 3 runs / 17 assertions / 0 failures / 0 errors / 0 skips                                |
| Targeted RuboCop for `test/integration/base_shared_rp_cell_selection_test.rb`         | Exit 0; no offenses                                                                     |
| `bin/rails test --verbose`                                                            | 7,599 runs / 51,023 assertions / 0 failures / 0 errors / 0 skips                        |

One coverage-enabled full run after the test correction reported 2 failures; a later verbose full
run and the final coverage run both reported 0 failures. The intermediate failure names were not
retained, so they remain unclassified and are not attributed to a code change.

## Coverage and maintenance changes

The stale `rails_performance` Valkey responsibility was removed from the Settings API, URL
responsibility registry, and development Valkey configuration. The accepted Valkey topology ADR
records that the old DB mapping is historical; the Coverband diagnostic store remains configured. No
environment variable, credential, CI file, or `.github/` file was changed in this slice. The shared
worktree still has a modified `.github/workflows/ci.yml`; it was left untouched.

The reachable `ArchitectureBaseline.write` maintenance task now has a public Rake-task test. It
loads and invokes `architecture:baseline`, compares the generated YAML with live measured counts,
and restores the exact prior file bytes in `ensure`. The test class runs serially because the task
writes a repository file. `Settings#performance` is no longer a coverage miss because the dead
accessor was removed. The focused Valkey and task tests passed **13 runs / 70 assertions**; targeted
RuboCop passed on the three changed Ruby files.

Repository-wide search found no application, library, or test caller for
`VerificationBase#step_up_satisfied?`; the only other occurrence was in historical ADR prose. That
unused wrapper was removed while preserving the concern's used step-up requirement and bootstrap
methods. The focused public step-up flow selection passed **14 runs / 95 assertions**. A refreshed
RuboCop run passed on all four changed Ruby files.

## Full coverage verification

After removing only the ignored SimpleCov resultset and lock, the final current-tree command was
`env -u POSTGRESQL_TEST_PREPARE_DATABASES COVERAGE=true PARALLEL_WORKERS=1 bin/rails test`. Minitest
passed **7,600 runs / 51,032 assertions / 0 failures / 0 errors / 0 skips**. The process exited
**2** because SimpleCov's unchanged aggregate minimums were not met:

| Metric   |                   Result | Minimum |
| -------- | -----------------------: | ------: |
| Lines    | 90.70% (31,265 / 34,470) |     98% |
| Branches |   62.02% (3,634 / 5,859) |     93% |
| Methods  |   88.16% (4,669 / 5,296) |     97% |

Earlier attempts before the final clean run included a parallel coverage run with **12 failures**, a
clean coverage run with **18 failures**, and a non-coverage run with **6 failures**, concentrated in
CSRF request/notification tests. The four-file focused CSRF run passed **44 runs / 1,218
assertions**; the preference CSRF file passed **12 / 36**, and the RP session concurrency test
passed **1 / 6**. The final clean full run passed without reproducing those failures. Their
order-sensitive root cause remains unconfirmed; the current full test result is green.

Vitest's previously recorded `bun run test:coverage` result remains **60 files / 594 tests passed**;
statements 100% (1,081 / 1,081), branches 100% (838 / 838), functions 100% (362 / 362), and lines
100% (1,054 / 1,054). No JavaScript or TypeScript changed in this slice.

No coverage threshold, ignore annotation, suppression, or exclusion changed.

## Current public/protected method inventory

The runtime inventory excludes generated `::HelperMethods` wrappers. The current 2,624 rows were
joined by source path and line to the clean single-worker `coverage/coverage.json` result:

| Visibility         |      Rows |   Reached | Exact misses | No location | Same-line name mismatch |
| ------------------ | --------: | --------: | -----------: | ----------: | ----------------------: |
| Public instance    |     1,646 |     1,389 |           97 |         140 |                      20 |
| Public class       |       917 |       913 |            2 |           0 |                       2 |
| Protected instance |        61 |        49 |           12 |           0 |                       0 |
| **Total**          | **2,624** | **2,351** |      **111** |     **140** |                  **22** |

The 111 exact misses comprise 93 controller actions whose request paths stop at unavailable Access
owner-data boundaries, nine shared concern methods (abstract fail-fast defaults, owner API response
handling, or verification helpers not reached in the current full-suite paths), two ORG IAM mutation
operations behind the Access boundary, and seven `ApplicationPolicy` role helpers retained by the
accepted authorization design. The 140 rows without an instrumentation location are generated
accessors, and the 22 same-line name mismatches are dynamic aliases, delegates, or framework
mappings, not independently executable method bodies. No private-method test seams were added.

The row-level joined inventory is retained in ignored
`tmp/coverage-task/public-protected-joined-final-2026-11-14.json` output.

## Disposable test database recovery

The Rails runs validated migration-owned constraints in APP Setting, ORG Setting and Occurrence test
databases. After confirming zero other sessions, only those three disposable databases were
individually dropped, recreated and migrated using their writer-specific Rails tasks. A final
read-only check after the last test and DatabaseConsistency run found:

| Test store  | Migration receipts | Unvalidated FKs | Unvalidated CHECKs | Other sessions |
| ----------- | -----------------: | --------------: | -----------------: | -------------: |
| APP Setting |            17 / 17 |               5 |                  0 |              0 |
| ORG Setting |            17 / 17 |               9 |                  0 |              0 |
| Occurrence  |          118 / 118 |              63 |                  0 |              0 |
| Chronicle   |            34 / 34 |               0 |                  0 |              0 |

The final post-rebuild
`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency`
run exited **0**, printed “No configuration files were provided,” and reported no findings. No
schema or migration changed in this coverage slice. No production, shared, Queue, or other database
was operated on.

## Remaining acceptance

Vitest meets its configured thresholds, and the final full Minitest run passes. All three aggregate
SimpleCov thresholds remain below minimum, and 111 exact public/protected misses remain with 162
non-one-to-one instrumentation rows. Targeted checks passed, but the coverage specification remains
in `implementing` status. The coverage task is not complete.
