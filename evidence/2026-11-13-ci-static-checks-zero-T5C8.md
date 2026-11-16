# CI Static Checks Zero Work Order — Current Tree Result

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

Before this record, the shared worktree had 1,018 changed or untracked paths. Results describe that
combined tree. `.github/workflows/ci.yml` was already modified and was not edited for this work
order. `config/credentials/` has no changes. No reset, stash, commit, push, deployment, credential
edit, or database migration was made for this work order.

## Result

The no-suppression zero-findings target remains incomplete. The released DatabaseConsistency gem
reports one valid JSON-expression/partial-unique-index contract that it cannot recognize. A default
Gitleaks scan reports 128 current-snapshot matches; those require owner triage and include hashes,
fixtures and pre-existing worktree content. No checker configuration, allow-list, warning
suppression, or credential change was added.

The checker-source item is complete: the ignored local fork is not the dependency, the application
uses released `database_consistency` 3.1.2, and no `.database_consistency.yml` exists. No local
checker patch was kept. The findings were addressed in models/schema where they represented real
contracts; the remaining JSON expression finding is documented below.

## Changes and decisions

- Removed `.rubocop_todo.yml` and its inheritance; the no-TODO run now has zero offenses. No
  `rubocop:disable`, new exclusion, or weakened cop was added.
- Fixed real validation/index mismatches and the concern-hook/visibility issues found by the
  baseline. Current normal and frozen-string RuboCop checks pass.
- Restored the executable repository-knowledge checker and repaired current routing/documentation
  references instead of recreating obsolete IdP policy documents. Added a current Mermaid index,
  clarified diagram ownership, removed a stale third-party sign-in-button rule, and repaired current
  checklist/spec links and descriptions.
- Kept the valid `OperatorChronicle` JSON-text uniqueness validation and PostgreSQL partial
  expression unique index. The released checker compares regular uniqueness validator columns to
  index columns and does not understand this custom validator/expression pair. PostgreSQL-backed
  regression tests confirm duplicate tuples are rejected, including direct SQL. Weakening the
  contract to satisfy the checker would be incorrect.
- Kept Gitleaks findings visible. No values were printed or copied into this report. The historical
  scan used Rails credential text conversion and therefore cannot classify encrypted credential
  ciphertext as plaintext secrets; no history rewrite or credential action was taken.
- The read-only Herb comparison remains as recorded in `2026-11-13-ci-static-checks-zero-X2F7.md`:
  ERB Lint runs 16 configured linters here, Herb supplies a different HTML/ERB/accessibility and
  Action View rule set, Rails 8.2 and editor integrations are documented, parity is unproven, and no
  same-template speed benchmark was run. No tool switch was made; tool choice remains an owner
  decision.
- Migrations added for this CI static-check work order: 0. Existing database changes in the shared
  tree are not attributed to this work order.

## Check results

The initial and intermediate results are in `2026-11-13-ci-static-checks-zero-5KQ2.md`, `R4N8.md`,
`S2P6.md` and `X2F7.md`. This table records the latest available before/after counts; commands rerun
during this final pass are marked **current**.

| Check / command                                                                                                                                                      | Earlier count or result                                                                      | Latest count or result                                                                                                                                                             |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency` (**current**)                                                                                      | 11 after moving to the release; then 7; six presence false positives were subsequently fixed | Exit 1, 1 finding: `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`; no checker config                                                                                |
| `bundle exec rubocop --fail-level convention --format simple` (**current**)                                                                                          | No-TODO run had 1,183 offenses, then 43 concern-hook offenses                                | 2,816 files inspected, 0 offenses; `.rubocop_todo.yml` absent                                                                                                                      |
| `ruby scripts/check_frozen_string_literal_directives.rb` (**current**)                                                                                               | 3,972 directives in the prior revalidation                                                   | `frozen_string_directive_check_ok=3968`; no directive violations                                                                                                                   |
| `bundle exec rubocop --config .rubocop_frozen_string_literal.yml --only Style/FrozenStringLiteralComment,Style/DisableCopsWithinSourceCodeDirective .` (**current**) | 3,973 files, 0 offenses                                                                      | 3,969 files inspected, 0 offenses                                                                                                                                                  |
| `bundle exec erb_lint --lint-all` (**current**)                                                                                                                      | 1,201 files, 0 errors in earlier revalidation                                                | 1,510 files linted, 0 errors                                                                                                                                                       |
| `bundle exec i18n-tasks missing` (**current**)                                                                                                                       | 0 missing keys                                                                               | 0 missing translations                                                                                                                                                             |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` (**current**)                                                                                       | 0 warnings/errors                                                                            | 0 warnings, 0 errors                                                                                                                                                               |
| `scripts/check-repository-knowledge`                                                                                                                                 | 3 missing routed docs and 7 broken links in earlier run                                      | Pass after current-document/link repairs; selected evidence validation is recorded below                                                                                           |
| Gitleaks default rules, current source snapshot, no allow-list, redacted report                                                                                      | 128 `generic-api-key` matches                                                                | 128 matches: workflow 2, compose 1, evidence 6, archived worklog 2, research body-token hashes 107, avatar-transfer test fixtures 10; no values printed                            |
| Gitleaks all refs                                                                                                                                                    | Prior 248 and 24 counts were inconsistent                                                    | A later scan of 3,223 commits reported 309 generic-key matches while encrypted credential textconv was `cat`; not a plaintext-secret count and not classifiable from that scan     |
| Actionlint 1.7.12 on `.github/workflows/ci.yml`                                                                                                                      | System 1.7.7 did not recognize `ubuntu-slim`                                                 | Passed with cached 1.7.12 binary; SHA-256 `c872d6db8c6bf83a8eaa704fc93999f027d55dffbc63b8a6abdccb47df5f4cd4`                                                                       |
| `bin/bundler-audit check --update`                                                                                                                                   | No known vulnerable gems                                                                     | No known vulnerabilities; advisory database advanced to commit `305f8b079a23bf95d00c881842f366bb8db19f35`                                                                          |
| `bun audit --audit-level=moderate` (**current**)                                                                                                                     | 3 moderate advisories before dependency remediation                                          | No vulnerabilities across 388 packages                                                                                                                                             |
| `bun run check` (**current**)                                                                                                                                        | Earlier format check failed before correction                                                | Format, lint, typecheck, dead-code and OpenAPI checks passed; existing Knip `.css` hint remains                                                                                    |
| Isolated production Vite build                                                                                                                                       | Initial wrapper checked a manifest after cleanup                                             | Passed in isolated ignored `tmp/` output; manifest present and no development-runtime markers                                                                                      |
| Full Rails suite                                                                                                                                                     | Earlier counts varied with the shared tree (7,513 and 7,505 runs)                            | Latest coverage run: 7,499 tests / 50,191 assertions, 0 test failures/errors/skips; process exit 2 only because SimpleCov minima failed: line 90.37%, branch 62.01%, method 85.62% |
| Vitest                                                                                                                                                               | Earlier runs varied with the current tree (588/59 and 696/68)                                | Latest recorded coverage run passed; statements/functions/lines 100%, branches 99.7% (full command is in `2026-11-13-coverage-reachability-L6N2.md`)                               |
| `git diff --check` (**current**)                                                                                                                                     | Passed in prior evidence                                                                     | Passed                                                                                                                                                                             |

The focused PostgreSQL tests for the remaining JSON uniqueness rule passed 6 tests / 56 assertions
with no failures, errors or skips. The full Rails test suite had no test failures; the nonzero
coverage command status is solely from repository thresholds of line 98%, branch 93% and method 97%.

## Remaining findings and owner items

1. **DatabaseConsistency: 1.** Its `UniqueIndexChecker` does not map the `OperatorChronicle` custom
   JSON-text validator to the partial expression index. The checker's supported shape does not
   include this expression-index contract. Model and PostgreSQL tests exercise the invariant; no
   checker workaround or schema weakening is appropriate.
2. **Gitleaks: 128 current-snapshot matches.** The grouped
   `research/2026-10-22-test-value-audit/ duplicates.md` body-token hashes account for 107 matches,
   and fixture matches account for 10. Two matches are in the already-modified workflow. Remaining
   values are unclassified scanner matches. Credential/history triage remains an owner action;
   credentials and history were not changed.
3. **Coverage thresholds.** All Rails tests passed, but current line/branch/method percentages
   remain below the configured thresholds. They are recorded as a coverage failure, not a test
   failure.
4. **Herb/tool choice.** No parity or same-template performance result supports replacing ERB Lint;
   owner decision remains open.

## Final status

- RuboCop, frozen-string checks, ERB Lint, i18n, Brakeman, Actionlint 1.7.12, dependency audits,
  `bun run check`, the isolated production build, and test executions passed as described.
- The acceptance condition “every CI static check reports zero problems without suppression” is
  **not met** because DatabaseConsistency reports 1 finding and Gitleaks reports 128 current
  matches. Historical secret matches remain unclassified.
- `config/credentials/` is unchanged. `.github/workflows/ci.yml` remains the pre-existing dirty file
  and was not edited. No commit or push was made.
