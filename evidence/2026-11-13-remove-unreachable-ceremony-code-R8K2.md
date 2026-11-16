# Remove Unreachable Ceremony Code — Latest Revalidation

Date: 2026-11-13

Repository: `umaxica-apps-cosmos-governance`

HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

Before this record, `git status --porcelain=v1` reported 749 changed or untracked paths. The shared
worktree was heavily modified before this revalidation. The implementation and original per-item
audit are recorded in
[`2026-11-13-remove-unreachable-ceremony-code-Q7M2.md`](2026-11-13-remove-unreachable-ceremony-code-Q7M2.md);
the post-reset validation is in
[`2026-11-13-remove-unreachable-ceremony-code-N4C7.md`](2026-11-13-remove-unreachable-ceremony-code-N4C7.md).
This follow-up made no ceremony-source, schema, route, credential or CI workflow change. No commit,
push or deployment was made.

## Current caller search

The current search for removed sign-in/sign-up flow concerns, admission store/binding, refresh token
concern, OIDC connection concern, step-up ceremony grant/result/error/issuer, binding codecs,
sequence carrier and ceremony numeric-date helper returned no matches under `app/`, `lib/`,
`config/`, `db/`, `test/`, `src/` or `gait/`.

`CoreRpBridge` intentionally remains. Its two current includers are `CoreAppClientBridge` and
`CoreOrgOperatorBridge`; its removed `actor`, `subject` and `core?` methods remain absent. The
bridge models and persistence are retained. No current ceremony-only table was found. No table,
column, index, constraint, structure dump, row or migration was changed by this work order. The only
deleted `db/` file remains the unused `db/migration_support/sign_in_flow_state_storage.rb`; it was
not a schema migration or table definition. RP state/audit and withdrawal-history tables remain
owned and used, as documented in Q7M2.

## Revalidation

| Command                                                                                                                                                                                                                                                                                                                               | Result                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `RAILS_ENV=test bin/rails zeitwerk:check`                                                                                                                                                                                                                                                                                             | Passed: `All is good!`                                                                      |
| `RAILS_ENV=test bin/rails routes`                                                                                                                                                                                                                                                                                                     | Passed; 429 output lines.                                                                   |
| `POSTGRESQL_TEST_PREPARE_DATABASES=<isolated writer list> RAILS_ENV=test bin/rails test test/unit/security/authentication_mode_inventory_test.rb test/unit/security/authentication_context_operation_inventory_test.rb test/integration/step_up_required_response_shape_test.rb test/integration/withdrawal_ceremony_reentry_test.rb` | 20 runs, 4,321 assertions, 0 failures, 0 errors, 0 skips.                                   |
| `env -u COVERAGE POSTGRESQL_TEST_PREPARE_DATABASES=<isolated writer list> RAILS_ENV=test bin/rails test`                                                                                                                                                                                                                              | 7,513 runs, 49,702 assertions, 0 failures, 0 errors, 0 skips.                               |
| `bin/rubocop --fail-level convention`                                                                                                                                                                                                                                                                                                 | 2,831 files inspected, 0 offenses.                                                          |
| `bundle exec erb_lint --lint-all`                                                                                                                                                                                                                                                                                                     | 1,201 files, 0 errors.                                                                      |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                                                                                                                                                                                                                                      | 0 warnings/errors.                                                                          |
| `bun run check`                                                                                                                                                                                                                                                                                                                       | Passed format, lint, typecheck, dead-code and OpenAPI checks in the current worktree.       |
| `RAILS_ENV=test bundle exec database_consistency`                                                                                                                                                                                                                                                                                     | Exit 1 with the same 7 findings recorded in R4N8; no checker config or exclusion was added. |
| `git diff --check`                                                                                                                                                                                                                                                                                                                    | Passed.                                                                                     |

The focused and full Rails runs used the isolated, test-prefixed writer catalog. The test database
had already been dropped and rebuilt in the ceremony work recorded by N4C7; this follow-up changed
no schema and did not reset another environment. Ruby 4.0 emitted the installed `nanoid` gem's
frozen-string warnings during tests; there were no test failures.

The 7,513 full-suite count is 23 more than the post-reset N4C7 run. Later test additions account for
part of the change, but attribution to individual earlier work is not possible from the combined
uncommitted tree. A coverage-enabled full run was not repeated here; the latest recorded SimpleCov
threshold result remains 88.45% line, 59.57% branch and 81.09% method in N4C7, below configured
minimums. This standard test run does not imply coverage thresholds passed.

## Scope and remaining limits

The Access ownership boundary remains in place: Governance has no local OP sign-in, sign-up,
step-up, WebAuthn, TOTP, social callback or OP-session ceremony implementation. Live Access data API
and revocation commands remain external dependencies and the retained Governance paths fail closed
as recorded in Q7M2. This work did not edit `.github/workflows/ci.yml`, which was already modified
in the shared worktree. `git diff --name-only -- config/credentials` returned no paths.

The historical, checklist and diagram removals, retained RP/identity records, tables left for a
later migration decision, and full starting-list disposition are detailed in Q7M2. Current
DatabaseConsistency's 7 unrelated findings and the incomplete static-check zero target are recorded
in [`2026-11-13-ci-static-checks-zero-S2P6.md`](2026-11-13-ci-static-checks-zero-S2P6.md). No
ceremony table was removed to make those checks pass.
