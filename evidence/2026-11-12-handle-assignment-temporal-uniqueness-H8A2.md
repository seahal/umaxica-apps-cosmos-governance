# Handle assignment temporal uniqueness

- Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`.
- The worktree contained extensive pre-existing uncommitted changes. Results include those changes
  and this slice's changes to `app/models/handle_assignment.rb` and
  `test/models/handle_assignment_test.rb`; they are not clean-HEAD results.
- Contract: current assignments have `valid_to = infinity` and unique handle and avatar references.
  Finite historical candidates do not participate in those existing PostgreSQL partial indexes.
- Red: `bin/rails test test/models/handle_assignment_test.rb`, PostgreSQL 18.6, seed 36205:
  5 runs, 13 assertions, 1 failure, 0 errors, 0 skips. A finite historical candidate was incorrectly
  rejected beside a current assignment.
- Change: condition both current-only uniqueness validators on the candidate's infinity endpoint.
  No database indexes or migrations changed.
- Green: the same command, seed 54705: 5 runs, 20 assertions, 0 failures, 0 errors, 0 skips.
  Tests cover finite history creation/update, rejected history-to-current transition, duplicate
  current validation and PostgreSQL rejection when validation is bypassed.
- `bin/rubocop app/models/handle_assignment.rb test/models/handle_assignment_test.rb`:
  2 files inspected, no offenses.
- The sandboxed initial test attempt failed to connect to `primary`; the recorded Red/Green runs
  used approved execution outside the sandbox with the repository's configured PostgreSQL.
- Coverage and the aggregate DatabaseConsistency recheck are left to the coordinating run to avoid
  concurrent writes to the shared coverage artifact. No coverage percentage is asserted here.
