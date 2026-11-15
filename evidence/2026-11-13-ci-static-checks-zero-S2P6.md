# CI Static Checks Zero — Current Worktree Follow-up

Date: 2026-11-13

Repository: `umaxica-apps-cosmos-governance`

HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

Before this record, `git status --porcelain=v1` reported 748 changed or untracked paths. Results
describe the shared, heavily modified worktree. No commit, push, deployment, credential edit, CI
workflow edit, or database migration was made. The earlier full inventory and commands are in
[`2026-11-13-ci-static-checks-zero-R4N8.md`](2026-11-13-ci-static-checks-zero-R4N8.md).

## Changes and verification

- The latest test-only edits initially produced three ordinary RuboCop offenses. Safe corrections
  and one direct `Rails.root.join(...).read` correction removed all three.
- Moved the `BannerModel` framework declarations out of its inclusion hook and into its two concrete
  model classes, following `docs/architecture/method-visibility-and-concerns.md`. Existing model and
  query tests passed before and after the move; no schema or data changed. No new test was needed
  because the existing public behavior tests cover its validations, scopes, timing boundary and
  actor behavior.
- Regenerated the architecture baseline after that reduction. It now records 39 remaining
  `Umaxica/NoConcernInclusionHooks` offenses; the explicit-visibility baseline has zero.
- A fresh all-refs worktree snapshot scan used Gitleaks with default rules and `--redact`; no secret
  values were printed or copied into this record.

| Check                                                                                                                                                                       | Earlier / before this follow-up                                                           | Latest result                                                                                                                                                               |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RAILS_ENV=test bundle exec database_consistency`                                                                                                                           | 7 findings in R4N8                                                                        | Exit 1; the same 7 findings remain, with no configuration file.                                                                                                             |
| `bin/rubocop --fail-level convention`                                                                                                                                       | 2,830 files, 0 offenses                                                                   | 2,831 files, 0 offenses.                                                                                                                                                    |
| RuboCop without `.rubocop_todo.yml`                                                                                                                                         | 43 offenses on the first current-tree comparison: 40 hooks and 3 test formatting offenses | 39 `Umaxica/NoConcernInclusionHooks` offenses; no other offenses. `.rubocop_todo.yml` remains and has 39 hook entries.                                                      |
| `bin/rails architecture:baseline`                                                                                                                                           | 40 hook files in the prior generated baseline                                             | 39 hook files; 0 explicit-visibility offenses.                                                                                                                              |
| `bin/rails test test/tooling/architecture_baseline_test.rb test/models/client_banner_test.rb test/models/operator_banner_test.rb test/queries/current_banner_query_test.rb` | Banner tests passed before the move: 15 / 44                                              | 18 / 128; 0 failures, errors or skips.                                                                                                                                      |
| Full Rails suite, test database reset previously recorded in N4C7                                                                                                           | 7,483 runs / 49,520 assertions in R4N8                                                    | `env -u COVERAGE POSTGRESQL_TEST_PREPARE_DATABASES=<isolated writer list> RAILS_ENV=test bin/rails test`: 7,513 runs / 49,702 assertions / 0 failures / 0 errors / 0 skips. |
| `ruby scripts/check_frozen_string_literal_directives.rb`                                                                                                                    | 3,978 directives                                                                          | 3,979 directives.                                                                                                                                                           |
| Frozen-string RuboCop command from R4N8                                                                                                                                     | 3,979 files, 0 offenses                                                                   | 3,980 files, 0 offenses.                                                                                                                                                    |
| `bundle exec erb_lint --lint-all`                                                                                                                                           | 1,201 files, 0 errors                                                                     | 1,201 files, 0 errors.                                                                                                                                                      |
| `bundle exec i18n-tasks missing`                                                                                                                                            | 0 missing keys                                                                            | 0 missing keys.                                                                                                                                                             |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                                                                            | 0 warnings/errors                                                                         | 0 warnings/errors.                                                                                                                                                          |
| `bun run check`                                                                                                                                                             | Passed in R4N8                                                                            | Passed format, lint, typecheck, dead-code and OpenAPI checks; Knip retains its compiled-CSS hint.                                                                           |
| Actionlint                                                                                                                                                                  | System `actionlint` 1.7.7 did not recognize `ubuntu-slim`                                 | The previously checksum-verified 1.7.12 binary passed `.github/workflows/ci.yml`.                                                                                           |
| Gitleaks current snapshot, default rules, no allow-list, `--redact`                                                                                                         | 128 generic-api-key findings in R4N8                                                      | 128 findings across 10 files, all `generic-api-key`.                                                                                                                        |
| Gitleaks all refs                                                                                                                                                           | 24 matches in 2 commits in R4N8                                                           | Not rerun; HEAD and repository history are unchanged. The prior count and unresolved 248-to-24 discrepancy remain recorded in R4N8.                                         |
| `bin/bundler-audit check --update`, `bun audit --audit-level=moderate`, `bun run build`                                                                                     | Clean/no advisories/success in R4N8                                                       | Not rerun; dependency manifests and frontend source have not changed since R4N8.                                                                                            |

The full Rails test run emitted the installed `nanoid` gem's Ruby 4.0 frozen-string warnings; they
did not fail tests. The prior Vitest coverage run passed 696 tests across 68 files and the
configured 99% thresholds. It was not rerun because no frontend source changed after R4N8. The Rails
SimpleCov thresholds remain unmet as recorded in `evidence/2026-11-13-coverage-completion-D7Q4.md`.

## Findings that remain

### DatabaseConsistency: 7

The released gem reports the custom partial JSON-expression uniqueness for `OperatorChronicle`, plus
conditional-presence mismatches on `Bureau.name`, `Bureau.title`, `Agent.title`, `Enterprise.name`,
`Enterprise.title`, and `ClientPersona.title`. The current model guards preserve projected-record
saves while PostgreSQL enforces NOT NULL. The uniqueness validator and expression index preserve an
event-specific tuple. Changing either contract merely to satisfy this checker would alter current
behavior. No checker source, configuration, schema, validation or required index was suppressed or
weakened.

### RuboCop: 39

`BannerModel` was migrated from 40 to 39 hook files. The remaining hooks span shared model concerns
with many direct consumers (the current source search found 113 `ReferenceRecord`, 73 `PublicId`, 30
`Retainable`, and 52 `SurfaceInertiaPage` includers) and lifecycle/controller behavior. The
architecture document prohibits mechanical migration and requires tests for behavior being moved;
those groups remain open for focused migrations. No cop was disabled, no `Exclude` was added, and
the TODO file was not removed.

### Repository knowledge and secrets

`scripts/check-repository-knowledge` still reports three routed files missing from `AGENTS.md`:
`docs/mermaid/README.md`, `docs/mermaid/idp-state-machine-transition-inventory.md`, and
`docs/reference/third-party-sign-in-button-requirements.md`. The current HEAD split removed those
documents along with 148 Mermaid/reference files (26,228 lines). Their prior contents describe the
former local provider ceremonies and sign-in buttons; restoring that snapshot would misstate current
ownership. No replacement owner-authored contract or route decision is present, so no placeholder or
guessed document was created.

The current Gitleaks snapshot still has 128 matches, including two in the pre-existing modified
`.github/workflows/ci.yml`; the file was not edited. The prior all-refs scan found 24 matches in
encrypted development/test credentials and one fixture. The credential files remain unchanged,
history was not rewritten, and no allow-list was added. Clearing these findings requires the
credential/history owner actions listed in R4N8.

## Final status

The zero-findings acceptance remains **unmet**: DatabaseConsistency has 7 findings, the no-TODO
RuboCop run has 39 hook offenses, the knowledge checker has 3 missing owner documents, and Gitleaks
has 128 current-snapshot plus 24 previously observed all-refs matches. Other rerun static checks
passed as listed above. The full Rails suite passes at 7,513 / 49,702. No migrations were added;
credentials and CI workflow were not changed. No commit or push was made.
