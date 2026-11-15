# Remove Unreachable Ceremony Code — Final Revalidation

Date: 2026-11-13

Repository: `umaxica-apps-cosmos-governance`

HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71` Worktree: 716 changed or untracked paths were
present before this revalidation record; 717 after. The worktree was already heavily modified. No
commit, push, or deployment was made.

## Scope and prior implementation

The ceremony removal was implemented and recorded earlier in
`evidence/2026-11-13-remove-unreachable-ceremony-code-Q7M2.md`. This ordered follow-up did not
repeat or revert those deletions. It rechecked the starting list against the current application
tree, verified Rails boot/routes, reset only the isolated test environment, and reran the full Rails
suite. The earlier evidence remains the detailed file-by-file deletion and ownership record.

## Starting-list recheck

The current `app/`, `lib/`, `config/`, `db/`, and `test/` search for the removed ceremony symbols
found no current callers for:

- `FlowSignIn` / `SignInFlow` and `FlowSignUp`;
- `OpaqueAdmissionStore`;
- `AuthAdmissionBinding` and its former `SignFlow` duration reader;
- `RefreshTokenShared` and `OidcConnectionRecord`;
- OP ceremony grant/result decode APIs and the OP result issuer;
- `CoreRpBridge#actor`, `#subject`, `#core?`, and `core_actor_foreign_key`.

`CoreRpBridge` itself intentionally remains. Its only current includers found by the targeted search
are `CoreAppClientBridge` and `CoreOrgOperatorBridge`; its remaining bridge behavior is still used.
Other matches from the broader identity/step-up search are retained identity migrations and RP
state/audit code, including `RpStepUpStartIssuer` and `StepUpAuditIdentityConflictError`. They do
not restore the removed OP ceremony flows.

The earlier candidate audit remains current: Governance-local sign-in/sign-up, OTP/TOTP delivery and
challenge, local WebAuthn enrollment UI, social sign-in callback and OP ceremony-result consumers
with no application caller were deleted. Identity and credential records, credential management,
owner-side audit/history, RP-owned step-up state and the OIDC handoff remain. No ceremony-only
current table or column was dropped; the former unused
`db/migration_support/sign_in_flow_state_storage.rb` was migration support code, not a table
deletion. Its findings are detailed in the earlier evidence record.

## Test database reset and verification

The Rails database safety guard requires the configured test databases to use the fixed local
development PostgreSQL target and `test_` database names. The reset was scoped to `RAILS_ENV=test`:

```text
RAILS_ENV=test bin/rails db:drop
RAILS_ENV=test bin/rails db:create
POSTGRESQL_TEST_PREPARE_DATABASES=<the isolated writer list from config/ci.rb> RAILS_ENV=test bin/rails db:test:prepare
POSTGRESQL_TEST_PREPARE_DATABASES=<the isolated writer list from config/ci.rb> RAILS_ENV=test bin/rails test
```

All four commands succeeded. The list includes the disposable test Queue database because the
repository's required test writer catalog includes it. Existing migrations recreated its test
schema; no Queue migration, schema source, model, or application configuration was edited. No
development, production, or shared database was targeted.

The post-reset Rails suite passed: **7,483 runs, 49,520 assertions, 0 failures, 0 errors, 0 skips**.
The count is 7 runs below the earlier ceremony evidence's 7,490 and has 33 more assertions. The
combined dirty tree and changed test inventory prevent attributing that count difference to one
change; no tests failed.

| Command                                           | Result                                                                                                                                      |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `RAILS_ENV=test bin/rails zeitwerk:check`         | Passed: `All is good!`                                                                                                                      |
| `RAILS_ENV=test bin/rails routes`                 | Passed; route listing completed (429 output lines).                                                                                         |
| `bin/rubocop --fail-level convention`             | Passed in the current tree: 2,830 files, 0 offenses.                                                                                        |
| `bundle exec erb_lint --lint-all`                 | Passed: 1,201 files, 0 errors.                                                                                                              |
| `RAILS_ENV=test bundle exec database_consistency` | Still exits 1 with the seven findings listed in `evidence/2026-11-13-ci-static-checks-zero-R4N8.md`; they are not ceremony-removal changes. |
| `bun run check`                                   | Passed format, lint, typecheck, dead-code, and OpenAPI checks.                                                                              |
| `bin/rails test` after isolated test DB reset     | Passed: 7,483 / 49,520, no failures, errors, or skips.                                                                                      |
| `git diff --check`                                | Passed.                                                                                                                                     |

The latest complete check details, including Brakeman, frozen-string checks, RuboCop, Gitleaks,
dependency audits, Actionlint, and Vite, are recorded in
`evidence/2026-11-13-ci-static-checks-zero-R4N8.md`.

## Ownership and remaining limits

The current code preserves Access's OP ownership boundary: Governance no longer runs the deleted
provider ceremonies. Features that remain dependent on Access OP data fail closed as documented in
the earlier evidence; no empty-list fallback or test-only branch was added.

The seven DatabaseConsistency findings and other static-check owner decisions are recorded in the
CI-static evidence. This revalidation made no source, test, schema, migration, route, locale,
credential, or CI workflow changes. `config/credentials/development.yml.enc` and
`config/credentials/test.yml.enc` have no worktree diff. The zero-findings target from the separate
CI-static work order remains incomplete for its explicitly listed blockers; the ceremony-removal
implementation and its post-reset Rails suite are complete.
