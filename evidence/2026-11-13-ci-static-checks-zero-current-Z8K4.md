# CI Static Checks Zero — Current Revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree contained 1,091 changed or untracked paths before this record. Results describe
that combined tree. The pre-existing `.github/workflows/ci.yml` modification was not changed. No
credential, CI, schema, or migration file was edited for this revalidation. No production or shared
database was used. No commit, push, or deployment was made.

## Ordered work-order status

1. PS256 follow-up is complete at the repository boundary. The latest same-HEAD focused revalidation
   is [`2026-11-13-ps256-follow-up-D3F9.md`](2026-11-13-ps256-follow-up-D3F9.md): 413 tests / 1,332
   assertions passed. Live Access interoperability and owner-provisioned keys remain external
   checks.
2. This record completes the safe local execution of the CI static-check work order. The
   zero-findings acceptance remains open because DatabaseConsistency reports one unsupported
   expression-index shape and Gitleaks reports 118 current-tree matches. Neither was suppressed.
3. The later-added ceremony-code work order is already recorded complete in
   [`2026-11-13-remove-unreachable-ceremony-code-Z8M6.md`](2026-11-13-remove-unreachable-ceremony-code-Z8M6.md).

## Current checks

Counts below are from the current worktree. Previous results are in the linked CI evidence records;
the prior latest Gitleaks and full-suite counts were 118 and 7,500 / 50,185 respectively.

| Check                                                                                                             | Current result                                                                                                                                                                                                                                                                                           |
| ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency`                                                 | Exit 1, one finding: `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`. No `.database_consistency.yml` exists. Published gem version 3.1.2 is used; no `path:` dependency or local checker diff was found.                                                                                   |
| `bundle exec rubocop --fail-level convention --format simple`                                                     | 2,820 files, 0 offenses. `.rubocop_todo.yml` is absent.                                                                                                                                                                                                                                                  |
| `ruby scripts/check_frozen_string_literal_directives.rb`                                                          | Passed: 3,972 directives.                                                                                                                                                                                                                                                                                |
| Frozen-string RuboCop command                                                                                     | 3,973 files, 0 offenses.                                                                                                                                                                                                                                                                                 |
| `bundle exec erb_lint --lint-all`                                                                                 | 1,510 files, 0 errors. The installed parser emitted its Ruby 4.0 compatibility notice.                                                                                                                                                                                                                   |
| `bundle exec i18n-tasks missing`                                                                                  | 0 missing translations.                                                                                                                                                                                                                                                                                  |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                  | 0 warnings, 0 errors.                                                                                                                                                                                                                                                                                    |
| Gitleaks default-rule scan of the current tracked and unignored worktree snapshot, redacted output, no allow-list | 8,130 files scanned; 118 `generic-api-key` matches. Group counts: 107 body-token digests in `research/2026-10-22-test-value-audit/duplicates.md`; 6 historical evidence matches; 2 workflow matches; 2 archived work-log matches; 1 Compose image reference. No matched values were printed or retained. |
| `actionlint .github/workflows/ci.yml`                                                                             | System 1.7.7 failed on four existing `ubuntu-slim` labels. The available Actionlint 1.7.12 binary passed; SHA-256 `c872d6db8c6bf83a8eaa704fc93999f027d55dffbc63b8a6abdccb47df5f4cd4`.                                                                                                                    |
| `bin/bundler-audit check --update`                                                                                | No known vulnerable gems; advisory database commit `305f8b079a23bf95d00c881842f366bb8db19f35`.                                                                                                                                                                                                           |
| `bun audit --audit-level=moderate`                                                                                | No vulnerabilities across 388 packages.                                                                                                                                                                                                                                                                  |
| `bun run format:check`                                                                                            | Passed: 290 files.                                                                                                                                                                                                                                                                                       |
| `bun run lint`                                                                                                    | Passed.                                                                                                                                                                                                                                                                                                  |
| `bun run typecheck`                                                                                               | Passed.                                                                                                                                                                                                                                                                                                  |
| Production Vite build and CI runtime assertion                                                                    | Passed in an isolated temporary output: 2,093 modules transformed, manifest present, and no `jsx-dev-runtime` or `jsxDEV` match under the emitted assets. The shared local dotenv configuration affected an initial run; the re-run explicitly selected production mode. Temporary outputs were removed. |
| Full Rails test suite                                                                                             | Passed: 7,506 tests / 50,226 assertions / 0 failures / 0 errors / 0 skips. Only the configured test writer databases were used. Concurrency tests emitted expected `AccessOpDataUnavailableError` worker-thread reports; Minitest recorded no failures.                                                  |
| `git diff --check`                                                                                                | Passed.                                                                                                                                                                                                                                                                                                  |

The Herb comparison remains in
[`2026-11-13-ci-static-checks-zero-X2F7.md`](2026-11-13-ci-static-checks-zero-X2F7.md): ERB Lint and
Herb have different rule sets, parity and same-template speed were not established, and no tool
switch was made. No new ADR or tooling change is justified by the available comparison.

## Findings and limits

- The sole DatabaseConsistency report is the valid PostgreSQL partial expression unique index for
  the custom `OperatorChronicle` JSON tuple validator. The released checker's supported validator
  matching does not recognize that expression-index contract. Existing PostgreSQL-backed tests
  protect the uniqueness invariant; changing it to silence the checker would weaken the design.
- Gitleaks matches remain visible. The 107 research values are documented body-token digests; the
  other matches are in historical evidence, an archived work log, and image declarations. Their
  owner classification is unresolved. No file was deleted or rewritten, and no allow-list,
  suppression, or checker change was added.
- The overall zero-findings acceptance is **not met**: DatabaseConsistency has 1 finding and the
  current snapshot has 118 Gitleaks matches. Other listed checks passed.
- No migration was added. `config/credentials/` is unchanged. The pre-existing workflow diff was
  preserved. The test setup's migration scope included `test_queue_db`; its migrations were already
  current and no Solid Queue source or schema file was edited.

## Latest tracked-worktree secret scan (2026-11-13)

After the later coverage and database evidence updates, the tracked and unignored worktree snapshot
was rebuilt and scanned with default Gitleaks rules, no allow-list, redacted JSON output, and no
history scan. It contained **8,132 files** and returned **118 `generic-api-key` matches**: 107 in
`research/2026-10-22-test-value-audit/duplicates.md`, 6 in historical evidence, 2 in the
pre-existing dirty workflow, 2 in the archived work log, and 1 Compose image reference. The count
and groups are unchanged from the previous scan. No matched values were printed or retained; no
files were rewritten or suppressed. The scan report is ignored temporary output at
`tmp/ci-static-gitleaks-final-y7c4.json`.

## Post-OIDC cleanup static revalidation (2026-11-13)

After removing the unused OIDC client-secret registry path, the full
`bundle exec rubocop --fail-level convention --format simple` run inspected **2,819 files with no
offenses**. `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` reported **0 warnings
and 0 errors**. Focused registry RuboCop and the full coverage-enabled Rails test results are in
[`2026-11-13-coverage-oidc-registry-retirement-V9C2.md`](2026-11-13-coverage-oidc-registry-retirement-V9C2.md).
The CI workflow and credential files remain unchanged.
