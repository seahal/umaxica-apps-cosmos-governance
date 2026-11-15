# CI Static Checks Zero Work Order Evidence

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Branch: `feature`

The worktree was already heavily modified before this work order. Checks ran against the combined
worktree; no reset, stash, commit, push, deployment, or workflow edit was made. The credentials
status was empty before and after the work. The repository-local checker configuration
`.database_consistency.yml` remains absent. A local Bun install ran `lefthook install` despite
`LEFTHOOK=0`, updating local `.git/hooks`; the prior hook contents were not recorded, so they were
left as installed. No further dependency install was run.

## Result

**The zero-findings acceptance is not met.** The released checker and normal configured RuboCop run
are usable and several findings were removed, but seven database-consistency findings, 43 legacy
concern-hook offenses without the TODO file, historical secret-scanner findings, and three missing
repository-knowledge documents remain. Those findings are recorded below without suppressions.

## Changes

- Restored the documented, executable `scripts/check-repository-knowledge` helper from repository
  history because `config/ci.rb` and current documentation invoke it while the working tree did not
  contain it. The restored checker now starts directly and reports the missing documents listed
  below. It was not possible to infer or author their policy content safely.
- Replaced the ignored local `database_consistency` path dependency with the published gem
  `database_consistency` 3.1.2. Restored the ignored checker fork to its recorded clean commit
  before switching; no checker source change was retained and no checker configuration was added.
- Aligned email and telephone blind-index preflight validation with the partial unique-index
  contract: empty strings are not skipped as if they were NULL. The validator now skips only NULL
  digest values; both models use `allow_nil: true`.
- Added explicit declarations for the 1,140 methods that were public by Ruby default. Their runtime
  visibility was preserved. RuboCop's visibility-cop inventory is now zero.
- Applied safe RuboCop autocorrection to 76 access-modifier spacing offenses introduced by those
  declarations.
- Fixed `ArchitectureBaseline` output so a cop with no exclusions emits `Exclude: []`. The existing
  architecture-baseline consistency test had exposed the generated empty `Exclude:` value as YAML
  `nil`.
- Removed unused `linkinator` and its dependency tree. Scoped the Tailwind Typography
  selector-parser override to fixed release 6.1.5; the separate Herb parser remains at 7.1.7.
- No database migration, schema dump, credential, workflow, or schema constraint changed.

## Check Results

| Check                                                      | Baseline / initial result                                                                    | Latest result                                                                                             |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Official `database_consistency`                            | 11 findings after switching to released gem                                                  | 7 findings; exit 1; no config file                                                                        |
| RuboCop, no TODO inheritance                               | 1,183 offenses: 1,140 explicit visibility and 43 inclusion hooks                             | 43 inclusion hooks remain after fixing all visibility and 76 safe layout offenses                         |
| Normal `bin/rubocop --fail-level convention`               | Existing TODO-backed gate                                                                    | 2,927 files, zero offenses, exit 0                                                                        |
| Frozen-string directive script                             | No prior finding recorded                                                                    | `frozen_string_directive_check_ok=4076`                                                                   |
| Frozen-string RuboCop                                      | No prior finding recorded                                                                    | 4,076 files, zero offenses, exit 0                                                                        |
| ERB Lint                                                   | No prior finding recorded                                                                    | 1,203 files, zero errors, exit 0                                                                          |
| `i18n-tasks missing`                                       | No prior finding recorded                                                                    | No missing translations, exit 0                                                                           |
| Brakeman                                                   | No prior finding recorded                                                                    | 0 errors, 0 warnings, exit 0                                                                              |
| Gitleaks history scan                                      | No clean-history baseline in this work order                                                 | 248 findings (`generic-api-key`, `private-key`), exit 1                                                   |
| Gitleaks current snapshot, default rules and no allow-list | No snapshot baseline in this work order                                                      | 128 `generic-api-key` findings; 2 are in uncommitted `ci.yml` lines 392 and 675; no secret values printed |
| Actionlint                                                 | Installed 1.7.7 incorrectly rejected `ubuntu-slim`                                           | Downloaded 1.7.12 accepted `.github/workflows/ci.yml`, exit 0                                             |
| Ruby gem audit                                             | No known vulnerable gems                                                                     | 0 known vulnerable gems; advisory DB commit `4d71b123428e33f694e805ce15351ee3d8d62ef7`                    |
| Bun audit                                                  | 3 moderate advisories                                                                        | 0 advisories across 388 packages, exit 0                                                                  |
| `bun run check`                                            | First attempt failed package formatting                                                      | Formatting, lint, typecheck, dead-code and OpenAPI checks passed, exit 0                                  |
| Vitest coverage                                            | No prior result recorded in this work order                                                  | 68 files / 696 tests passed; statements 100%, branches 99.7%, functions 100%, lines 100%                  |
| Isolated production Vite build                             | First wrapper checked the manifest after deleting its temporary output                       | Build exit 0; manifest present; no `jsx-dev-runtime`/`jsxDEV` marker                                      |
| Repository knowledge checker                               | Command referenced by CI/docs was absent                                                     | Restored checker runs but reports three missing documents; see below                                      |
| Full Rails suite                                           | Coverage evidence C8N4: 7,657 runs / 51,376 assertions; later PS256 evidence: 7,673 / 51,620 | Repeated with same command: 7,673 runs / 50,802 assertions / 0 failures / 0 errors / 0 skips              |
| `git diff --check`                                         | Not recorded                                                                                 | Passed                                                                                                    |

Ruby ERB Lint emitted the existing notice that `parser/ruby33` is running on Ruby 4.0.9. The Vite
build emitted a non-fatal React Compiler warning for `CookieBanner.tsx`; the component was skipped
for optimization and the production bundle succeeded. The first isolated-build wrapper's failure was
its own check order: it removed the temporary directory before testing the manifest; the corrected
wrapper checked the manifest before cleanup.

The Rails assertion total is **818 below** the immediately preceding PS256 evidence even though the
run count is unchanged. Repeating the same command reproduced 7,673 / 50,802. No test file was
changed by this work order, and no cause for the assertion-count difference was established. This
remains an observed, unexplained difference; the test run passed. The comparison is affected by the
worktree's prior test edits and the existing test-database state; no test-database reset was run.

## Findings That Remain

### Database consistency

The 7 findings from `RAILS_ENV=test bundle exec database_consistency` without configuration are:

- `OperatorChronicle` unique JSON-expression halt index: its custom `jsonb_text_uniqueness`
  validator and partial expression index enforce the event-18 tuple, but the released checker does
  not recognize that validator/index shape. Existing model and direct-PostgreSQL behavior tests
  cover the tuple. Replacing it with a broader uniqueness rule would change the owned contract.
- Six conditional column-presence findings: `Bureau.name`, `Bureau.title`, `Agent.title`,
  `Enterprise.name`, `Enterprise.title`, and `ClientPersona.title`. These models use
  `has_attribute?`-guarded validations to preserve projected-record saves; PostgreSQL already owns
  the NOT NULL constraint. Removing those guards broke existing projected-title tests, so neither
  the validation nor the schema was weakened.

The email and telephone partial-index findings were the four findings removed by the validator
change. No migration was added. The remaining seven are not configured away and are not reported as
zero.

### RuboCop

`.rubocop_todo.yml` and its inheritance remain because 43 `Umaxica/NoConcernInclusionHooks` offenses
still exist in 43 concerns. The current architecture documentation requires tests for each
behavioral migration; these hooks install callbacks, validation, associations, scopes, helpers,
attributes, or similar host behavior, often through many transitive includers. Their behavior and
ordering were not mechanically relocated. The TODO was reduced to those 43 files; the
`Umaxica/ExplicitMethodVisibility` exclusion is now empty and its count is zero. No cop was
disabled, no RuboCop rule was weakened, and no `rubocop:disable` was added. Because the 43 hooks
remain, the plan's requirement to empty/delete `.rubocop_todo.yml` is not fulfilled.

### Repository knowledge and secrets

The restored checker reports missing files referenced by the current `AGENTS.md`:

- `docs/mermaid/README.md`
- `docs/mermaid/idp-state-machine-transition-inventory.md`
- `docs/reference/third-party-sign-in-button-requirements.md`

Their normative content was not reconstructed from guesses. Owner review is needed to restore the
current documents or correct the routed requirements.

The history scan found 248 historical matches. The work order prohibits push and this work did not
rewrite repository history. The two current-snapshot matches are in the pre-existing uncommitted
workflow; their values were not printed or changed. They need secret-owner triage before any
history/credential action. The repository's existing `.gitleaks.toml` was not changed; the 128-count
snapshot deliberately used Gitleaks default rules without loading that allow-list.

## TDD and Regression Verification

- Existing blind-index contract tests were red on the released checker/model contract (`:ok`
  expected versus `:fail` actual). The validator/model correction passed the focused run: **37 tests
  / 116 assertions / 0 failures / 0 errors / 0 skips**.
- The full Rails suite first exposed one error in the architecture-baseline test because generated
  `Exclude:` parsed as `nil`. After fixing the generator, the existing test file passed **3 tests /
  92 assertions** and the full suite passed **7,673 / 50,802 / 0 failures / 0 errors / 0 skips**.
- JavaScript coverage passed **696 tests / 68 files**.
- No test files or database migrations were added in this work order. No schema migration was
  applied, and no database was reset.

Commands run included:

```text
RAILS_ENV=test bundle exec database_consistency
bin/rubocop --fail-level convention
bundle exec rubocop --config .rubocop-no-todo.yml --fail-level convention -a
bundle exec erb_lint --lint-all
bundle exec i18n-tasks missing
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit check --update
bun audit --audit-level=moderate
bun run check
bun run test:coverage
env -u POSTGRESQL_TEST_PREPARE_DATABASES bin/rails test
env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBYOPT=-W0 RAILS_ENV=test bin/rails test
scripts/check-repository-knowledge
git diff --check
```

`bin/ci`, the Rails-server smoke step, and the isolated coverage gate were not run. The full Rails
suite and Vitest coverage suite were run directly. No production or shared database was touched.

## Read-only Herb Comparison

The repository uses `erb_lint` 0.9.0 and `@herb-tools/linter` 0.11.2. No tool switch was made.

- **Rule coverage:** the current ERB Lint setup runs 16 linters, including repository-specific
  `ErbSafety`, `NoJavascriptTagHelper`, `NoUnusedDisable`, and RuboCop checks. Herb builds a
  combined HTML/ERB tree and offers HTML, accessibility, and Action View checks. These sets are not
  proven equivalent; no parity run was performed.
  [ERB Lint README](https://github.com/Shopify/erb_lint/blob/main/README.md),
  [Herb overview](https://herb-tools.dev/overview),
  [Herb linter rules](https://herb-tools.dev/linter/rules/).
- **Rails 8.2:** Herb documents Rails 8.2 integration and its engine; this repository currently
  targets Rails 8.2.0.alpha. ERB Lint remains the measured CI checker and passed all 1,203
  templates. [Herb overview](https://herb-tools.dev/overview).
- **Speed:** neither checker was benchmarked on the same template set; no speed conclusion is
  recorded.
- **Editor support:** Herb documents VS Code and language-server integrations for editors including
  Zed, Neovim, Nova, and Sublime. This is useful additional feedback, but it does not establish CI
  parity. [Herb editor integrations](https://herb-tools.dev/integrations/editors/vscode),
  [Herb language server](https://herb-tools.dev/projects/language-server).

The tool-choice question remains with the owner as required by the work order.

## Final Status

- Official checker is installed with no path dependency or configuration suppression.
- Normal RuboCop and the listed Ruby, ERB, JavaScript, build, and Ruby/Bun dependency checks pass.
- The no-suppression target remains **incomplete**: database consistency has 7 findings; RuboCop
  without TODO has 43 findings; the knowledge checker has 3 missing-document findings; Gitleaks has
  248 historical findings and 128 default-rule current-snapshot matches.
- Tests: full Rails 7,673 passed / 0 failed / 0 errors; Vitest 696 passed / 0 failed.
- Migrations added: 0. Credentials changed: no. Workflow edited by this work order: no.
- No commit or push was made.
