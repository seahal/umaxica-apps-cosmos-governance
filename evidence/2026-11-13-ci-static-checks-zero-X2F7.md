# CI Static Checks Zero Work Order Evidence

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Branch: `feature`

The shared worktree already contained 950 changed or untracked paths before this evidence file was
added. Results describe that combined worktree. No reset, stash, commit, push, deployment, database
migration, or CI workflow edit was made for this work order. `.github/workflows/ci.yml` was already
modified in the worktree; it remains untouched by this work. No credentials file was edited.
`git status --short config/credentials` was empty.

## Result

The static-check zero acceptance remains incomplete. The no-TODO RuboCop run is now clean, but
DatabaseConsistency reports seven findings, the repository-knowledge checker reports three missing
owner-authored documents, and Gitleaks reports 128 current-snapshot matches. Historical Gitleaks
counts in earlier evidence are not reliable; the correction is recorded below. Findings remain
visible and were not suppressed.

## Changes in this work order

- Replaced the ignored local DatabaseConsistency path dependency with published
  `database_consistency` 3.1.2. The ignored fork had no local tracked diff at inspection. The
  dependency no longer uses `path:` and `.database_consistency.yml` remains absent. The unrelated
  `FIXME` now in `Gemfile` concerns the local `rails-erd` fork, not DatabaseConsistency.
- Corrected email and telephone blind-index preflight validations to match their partial unique
  indexes: empty strings are not treated as `NULL`; both validators use `allow_nil: true`.
- Removed all 43 `Umaxica/NoConcernInclusionHooks` offenses by moving each host behavior into
  explicit model or controller declarations. Removed `.rubocop_todo.yml` and its inheritance line;
  no new `rubocop:disable`, exclusion, or weakened cop was added.
- Restored the repository-knowledge checker referenced by CI and current instructions. It runs and
  identifies the missing routed documents below; no placeholder policy documents were invented.
- No database migration, schema dump, credential, or CI workflow was changed.

## Check results

| Check                                                                                                                   | Earlier or initial result                                      | Latest result                                                                                                                                                                                                                                        |
| ----------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RAILS_ENV=test bundle exec database_consistency`                                                                       | 11 findings after switching to the release; then 7             | Exit 1, same 7 findings, no configuration file                                                                                                                                                                                                       |
| `bin/rubocop --fail-level convention --format simple`                                                                   | 43 no-TODO `Umaxica/NoConcernInclusionHooks` offenses          | 2,824 files inspected, 0 offenses                                                                                                                                                                                                                    |
| `bundle exec rubocop --config .rubocop/architecture_measure.yml --only Umaxica/NoConcernInclusionHooks --format simple` | 43 hook offenses                                               | 1,547 files inspected, 0 offenses                                                                                                                                                                                                                    |
| `bin/rails architecture:baseline` and architecture baseline test                                                        | Hook inventory nonzero                                         | 0 hook and 0 explicit-visibility offenses; `test/tooling/architecture_baseline_test.rb`: 3 runs / 15 assertions, pass                                                                                                                                |
| `ruby scripts/check_frozen_string_literal_directives.rb`                                                                | 3,979 directives in the prior evidence                         | `frozen_string_directive_check_ok=3972`                                                                                                                                                                                                              |
| Frozen-string RuboCop command                                                                                           | 3,980 files, 0 offenses in the prior evidence                  | 3,973 files, 0 offenses                                                                                                                                                                                                                              |
| `bundle exec erb_lint --lint-all`                                                                                       | 1,201 files, 0 errors                                          | 1,201 files, 0 errors                                                                                                                                                                                                                                |
| `bundle exec i18n-tasks missing`                                                                                        | 0 missing keys                                                 | 0 missing keys                                                                                                                                                                                                                                       |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                        | 0 warnings/errors                                              | 0 warnings/errors                                                                                                                                                                                                                                    |
| Repository knowledge: `scripts/check-repository-knowledge`                                                              | Three missing documents                                        | Exit 1, same three missing documents                                                                                                                                                                                                                 |
| Gitleaks current snapshot, default rules, no allow-list, redacted JSON                                                  | 128 `generic-api-key` matches in the prior snapshot            | 128 matches, all `generic-api-key`; no values printed                                                                                                                                                                                                |
| Gitleaks all refs                                                                                                       | Earlier reports said 248, then 24                              | Those counts are superseded as unreliable; see historical scan correction below                                                                                                                                                                      |
| `actionlint .github/workflows/ci.yml`                                                                                   | System 1.7.7 rejected four `ubuntu-slim` labels                | Downloaded 1.7.12 passed. Current binary SHA-256 was `c872d6db8c6bf83a8eaa704fc93999f027d55dffbc63b8a6abdccb47df5f4cd4`; the previously recorded `8aca...` checksum does not match this binary, so no release-checksum verification is claimed here. |
| `bin/bundler-audit check --update`                                                                                      | No known vulnerable gems                                       | No vulnerable gems; advisory database commit `4d71b123428e33f694e805ce15351ee3d8d62ef7`                                                                                                                                                              |
| `bun audit`                                                                                                             | Three moderate advisories before the earlier dependency update | No vulnerabilities across 388 packages                                                                                                                                                                                                               |
| `bun run check`                                                                                                         | Previously passed                                              | Format, lint, typecheck, dead-code and OpenAPI checks passed. Knip retains its existing compiled-CSS configuration hint.                                                                                                                             |
| `bun run test:coverage`                                                                                                 | 696 tests in 68 files in earlier evidence                      | 588 tests in 59 files; statements, branches, functions and lines all 100%. 99 source files fully covered; 83 empty files skipped.                                                                                                                    |
| `bun run build`                                                                                                         | Production build passed previously                             | Production build passed. A scan of the shared `public/vite/assets` directory found stale development-runtime markers from older assets; an isolated output build had a manifest and no `jsx-dev-runtime` or `jsxDEV` marker.                         |
| `bundle outdated` / `bun outdated`                                                                                      | Not recorded                                                   | Both reporting commands ran; `bundle outdated` listed available gem updates and exited 1 (the CI step is `                                                                                                                                           |     | true`); `bun outdated` exited 0. No dependency update was made here. |
| Full Rails suite with configured test writer databases only                                                             | 7,513 runs / 49,702 assertions in earlier worktree evidence    | 7,505 runs / 49,807 assertions / 0 failures / 0 errors / 0 skips                                                                                                                                                                                     |
| `git diff --check`                                                                                                      | Passed previously                                              | Passed                                                                                                                                                                                                                                               |

The Rails suite used the writer database names derived from the current `RAILS_ENV=test` Rails
configuration. It did not prepare, reset, or connect to production or shared databases. The full
suite emitted existing Ruby 4.0 frozen-string warnings from the installed `nanoid` gem.

The isolated production Vite verification used `VITE_RUBY_PUBLIC_OUTPUT_DIR` under ignored `tmp/` so
the check did not scan stale assets left in `public/vite/assets`. The build output included the
existing non-fatal large-chunk warning. The failed attempt to use `bunx` was a missing executable;
the installed `node_modules/.bin/vite` command completed the isolated build successfully.

### TDD and regression checks

- The architecture-baseline test was first run while the TODO file was still present and failed its
  two no-TODO expectations. After deleting the TODO file and inheritance, it passed 3 runs / 15
  assertions.
- The new Retainable host inventory assertion first failed, identifying all 28 direct hosts without
  explicit declarations; after migrating the hosts it passed in the 17-run / 53-assertion focused
  test.
- The ClientWithdrawalFlow direct-inclusion invariant first failed (1 run / 2 assertions). After
  declaring its required concerns and behavior directly, the flow, withdrawal, retention and purge
  regression set passed 50 runs / 209 assertions.
- Other migrated concern groups were covered by their existing focused model/controller tests; the
  full Rails suite passed 7,505 / 49,807 with no failures or skips.

## Findings retained

### DatabaseConsistency: 7

The current released checker reports the custom JSON-expression uniqueness on
`OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`, plus conditional-presence findings on
`Bureau.name`, `Bureau.title`, `Agent.title`, `Enterprise.name`, `Enterprise.title`, and
`ClientPersona.title`. The JSON tuple is enforced by a PostgreSQL partial expression index and a
custom validator that the checker does not recognize. The six presence validations guard projected
records with `has_attribute?`; PostgreSQL owns the `NOT NULL` constraints. Existing tests protect
those behaviors. No schema or validation contract was weakened to silence the checker.

### Repository knowledge: 3 missing documents

The checker reports:

- `docs/mermaid/README.md`
- `docs/mermaid/idp-state-machine-transition-inventory.md`
- `docs/reference/third-party-sign-in-button-requirements.md`

These are owner-maintained routed contracts. Their replacement content cannot be inferred safely
from the implementation, so no placeholder was added.

### Gitleaks: current snapshot and history correction

The current source snapshot was built from tracked and unignored working-tree files and scanned with
`tmp/ci-static-default-gitleaks.toml` (`useDefault = true`), no allow-list, and redacted JSON
output. It reported 128 `generic-api-key` matches. Values were not printed or copied into this
record. Credential files were not edited, and repository history was not rewritten.

The redacted report grouped the 128 matches as follows: `.github/workflows/ci.yml` (2, lines 392 and
675), `compose.yaml` (1), three historical evidence files (3 total), one archived work log (2),
`research/2026-10-22-test-value-audit/duplicates.md` (107), and two avatar transfer test files (10
total). The research report labels the 107 values as body-token hashes; these are content-group
digests, not confirmed credentials. The remaining matches are unclassified scanner matches, not
confirmed secrets. The two workflow matches were in the pre-existing modified workflow and remain
outside this work order's edits.

Earlier evidence claimed 248 historical matches and later 24. A later completed scan covered 3,223
commits after configuring Rails credential text conversion as `cat` and reported 309
`generic-api-key` matches. That treats encrypted credential ciphertext as text and cannot be read as
309 confirmed secrets. The earlier 24-match scan was partial because Rails credential textconv
failed to boot without production database configuration. Therefore the prior 24 and 248 figures are
not reliable all-history counts; the available scan does not establish a plaintext-secret count. Any
credential/history action remains for the owner, and no history rewrite or credential edit was
authorized.

### Herb comparison (read-only)

No tool switch was made. ERB Lint 0.9.0 runs 16 configured linters in this repository, including
repository-specific safety and RuboCop integration. Herb combines HTML and ERB parsing and offers
HTML, accessibility and Action View rules. The rule sets have not been proven equivalent. Herb
documents Rails 8.2 integration and editor/language-server integrations; no same-template speed
benchmark was run. The owner retains the tool-choice decision. References:
[ERB Lint README](https://github.com/Shopify/erb_lint/blob/main/README.md),
[Herb overview](https://herb-tools.dev/overview),
[Herb rules](https://herb-tools.dev/linter/rules/),
[Herb editor integrations](https://herb-tools.dev/integrations/editors/vscode).

## Final status

- RuboCop, frozen-string checks, ERB Lint, i18n, Brakeman, actionlint 1.7.12, gem and Bun audits,
  `bun run check`, the isolated production build, and the Rails/Vitest test suites passed as listed.
- The requested zero-findings target is **not met**: DatabaseConsistency has 7 findings, the
  repository-knowledge checker has 3 missing-document findings, and current-snapshot Gitleaks has
  128 findings. Historical Gitleaks matches remain unclassified.
- No migrations, credential changes, or CI workflow edits were made for this task. No commit or push
  was made.
