# CI Static Checks Zero Follow-up

Date: 2026-11-13

Repository: `umaxica-apps-cosmos-governance`

HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71` Worktree: 715 changed or untracked paths were
present before this record was created; 716 after. The worktree was already heavily modified, so
results describe the combined tree. No commit, push, deployment, credential edit, CI workflow edit,
or database migration was made in this follow-up.

## Result

The static-check zero target remains incomplete. The released DatabaseConsistency gem runs without
repository configuration but reports seven findings; the no-TODO RuboCop comparison has 43 concern
inclusion-hook offenses; the repository-knowledge checker reports three missing owner-authored
documents; and secret scanning reports findings in historical/fixture material and in the
pre-existing dirty workflow. Those items are left visible rather than suppressed or rewritten
without the required ownership, credential, or history decisions.

## Check results

The earlier baseline and remediation are recorded in
`evidence/2026-11-13-ci-static-checks-zero-5KQ2.md`. This table records the latest reruns and the
before/after counts available from that baseline.

| Check and command                                                                                                                                                                                                                                            | Earlier result                                                                                                 | Latest result                                                                                                                                                                                                                                                                                                                                    |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `RAILS_ENV=test bundle exec database_consistency`                                                                                                                                                                                                            | 11 findings after switching from the ignored path fork to the released gem; then reduced to 7                  | Exit 1, same 7 findings; no `.database_consistency.yml`                                                                                                                                                                                                                                                                                          |
| `bin/rubocop --fail-level convention`                                                                                                                                                                                                                        | Existing TODO-backed gate                                                                                      | 2,830 files, 0 offenses                                                                                                                                                                                                                                                                                                                          |
| `bundle exec rubocop --config .rubocop-no-todo.yml --fail-level convention`                                                                                                                                                                                  | Earlier no-TODO run: 1,183 offenses, then 43 after explicit visibility cleanup and safe formatting corrections | 43 `Umaxica/NoConcernInclusionHooks` remain in the latest recorded run; normal RuboCop passes. The transient comparison config was absent on this recheck, so the no-TODO command itself was not repeated.                                                                                                                                       |
| `ruby scripts/check_frozen_string_literal_directives.rb`                                                                                                                                                                                                     | 4,076 directives                                                                                               | `frozen_string_directive_check_ok=3978`                                                                                                                                                                                                                                                                                                          |
| `bundle exec rubocop --config .rubocop_frozen_string_literal.yml --only Style/FrozenStringLiteralComment,Style/DisableCopsWithinSourceCodeDirective .`                                                                                                       | 4,076 files, 0 offenses                                                                                        | 3,979 files, 0 offenses                                                                                                                                                                                                                                                                                                                          |
| `bundle exec erb_lint --lint-all`                                                                                                                                                                                                                            | 1,203 files, 0 errors                                                                                          | 1,201 files, 0 errors                                                                                                                                                                                                                                                                                                                            |
| `bundle exec i18n-tasks missing`                                                                                                                                                                                                                             | 0 missing keys                                                                                                 | 0 missing keys                                                                                                                                                                                                                                                                                                                                   |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                                                                                                                                                             | 0 warnings/errors                                                                                              | 0 warnings/errors                                                                                                                                                                                                                                                                                                                                |
| `scripts/check-repository-knowledge`                                                                                                                                                                                                                         | The command was initially absent; restoring it exposed 3 missing documents                                     | Exit 1, same 3 missing documents: `docs/mermaid/README.md`, `docs/mermaid/idp-state-machine-transition-inventory.md`, and `docs/reference/third-party-sign-in-button-requirements.md`                                                                                                                                                            |
| Gitleaks current snapshot, default rules and no allow-list: `gitleaks detect --no-git --source tmp/ci-static-worktree-snapshot --config tmp/ci-static-default-gitleaks.toml --redact --report-format json --report-path tmp/ci-static-gitleaks-current.json` | 128 `generic-api-key` findings; 2 in the pre-existing dirty workflow                                           | 128 findings across 10 files, all `generic-api-key`; the two workflow locations remain at lines 392 and 675. Values were not printed.                                                                                                                                                                                                            |
| Gitleaks all refs, default rules and no allow-list: `gitleaks detect --log-opts='--all' --config tmp/ci-static-default-gitleaks.toml --redact --report-format json --report-path tmp/ci-static-gitleaks-all-refs.json`                                       | Prior evidence reports 248 historical findings                                                                 | 24 findings across 3 files and 2 commits: 23 in encrypted development/test credentials and 1 test fixture. No credential file was read for values or edited. The 248-to-24 difference between scans is unresolved; both reports were redacted and this run's report contains only the 24 matches under the current Gitleaks build/default rules. |
| `actionlint .github/workflows/ci.yml`                                                                                                                                                                                                                        | Installed 1.7.7 reported four unsupported `ubuntu-slim` labels                                                 | Official release 1.7.12 passed the entire workflow. The downloaded Linux binary matched the published SHA-256 `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8`. [Official release](https://github.com/rhysd/actionlint/releases/tag/v1.7.12)                                                                                   |
| `bin/bundler-audit check --update`                                                                                                                                                                                                                           | No known vulnerable gems                                                                                       | No vulnerable gems; advisory database updated to commit `4d71b123428e33f694e805ce15351ee3d8d62ef7` (2026-11-11).                                                                                                                                                                                                                                 |
| `bun audit --audit-level=moderate`                                                                                                                                                                                                                           | 3 moderate advisories before dependency update                                                                 | 0 advisories across 388 packages.                                                                                                                                                                                                                                                                                                                |
| `bun run format:check`, `bun run lint`, `bun run typecheck`                                                                                                                                                                                                  | Initial formatting check failed before correction                                                              | All passed.                                                                                                                                                                                                                                                                                                                                      |
| `bun run check`                                                                                                                                                                                                                                              | Initial run failed formatting before correction                                                                | Passed format, lint, typecheck, dead-code, and OpenAPI checks; Knip retained its existing `.css` compiled-extension hint.                                                                                                                                                                                                                        |
| `bun run build`                                                                                                                                                                                                                                              | The earlier isolated wrapper did not retain its output manifest for inspection                                 | Exit 0; production Vite build succeeded.                                                                                                                                                                                                                                                                                                         |
| Full Rails suite with the isolated test-database writer list passed through the environment                                                                                                                                                                  | Prior ceremony evidence: 7,490 runs / 49,487 assertions; PS256 follow-up: 7,483 / 49,520                       | 7,483 runs / 49,520 assertions / 0 failures / 0 errors / 0 skips. Counts are from the combined dirty tree; the seven-run difference from the ceremony evidence is not attributable to one change with certainty.                                                                                                                                 |
| `git diff --check`                                                                                                                                                                                                                                           | Passed in the prior evidence                                                                                   | Passed during this follow-up.                                                                                                                                                                                                                                                                                                                    |

The installed `database_consistency` gem is 3.1.2, with no `path:` dependency and no repository
checker configuration. Its version is the latest release shown by
[RubyGems](https://rubygems.org/gems/database_consistency/versions/3.1.2) for this date.
`vendor/fork/database_consistency` has no worktree changes. No migration was added.

## Findings retained for owners

DatabaseConsistency reports the custom JSON-expression uniqueness for `OperatorChronicle` and
conditional-presence mismatches on `Bureau.name`, `Bureau.title`, `Agent.title`, `Enterprise.name`,
`Enterprise.title`, and `ClientPersona.title`. The previous review records the existing
projected-record and partial-index contracts behind these guards. Weakening those contracts or
changing them solely for checker silence would be unsafe; no schema change or checker suppression
was made.

The 43 no-TODO RuboCop offenses are `Umaxica/NoConcernInclusionHooks`. Relocating the hooks requires
preserving callback, validation, association, scope and load-order behavior across their includers.
The worktree does not contain an accepted design decision for that refactor. No cop was disabled, no
exclusion was added, and the TODO file was not emptied or deleted.

The three missing repository-knowledge documents are routed by `AGENTS.md` as owner-maintained
contracts. Their requirements cannot be safely inferred from code. No placeholder documents were
created.

The current-snapshot Gitleaks report used a temporary default-rules-only configuration with no
allow-list. Its 128 findings span prior evidence/research samples, a test sample, `compose.yaml`,
and two locations in `.github/workflows/ci.yml`, which was already modified before this follow-up.
The all-refs scan found matches in `config/credentials/development.yml.enc`,
`config/credentials/test.yml.enc`, and one test fixture. The work order expressly forbids credential
edits; history rewriting and pushing are also outside this authorization. No secret values were
printed, copied into this record, or changed.

The all-refs Gitleaks count does not match the 248 count in the earlier evidence. This follow-up
used the installed Gitleaks build, `--log-opts='--all'`, the same default rules without an
allow-list, and redacted JSON output; it found 24 matches in two commits. Because the earlier
command/version metadata is not sufficient to reproduce its 248 count from this tree, the
discrepancy remains explicit rather than being treated as resolved.

## Read-only Herb comparison

No tool switch was made. The repository uses ERB Lint 0.9.0 with 16 configured linters, including
repository-specific safety checks and RuboCop integrations. Herb's combined HTML/ERB tree provides
HTML, accessibility, and Action View checks; the rule sets are not proven equivalent. Herb documents
Rails 8.2 integration and editor/language-server integrations, while this application targets Rails
8.2.0.alpha. Neither tool was benchmarked on the same template set. No parity or speed claim is
made. The owner retains the tool-selection decision. Primary documentation reviewed:
[ERB Lint](https://github.com/Shopify/erb_lint), [Herb overview](https://herb-tools.dev/overview),
[Herb linter rules](https://herb-tools.dev/linter/rules/), and
[Herb editor integrations](https://herb-tools.dev/integrations/editors/vscode).

## Scope confirmation

- Credentials are unchanged:
  `git diff -- config/credentials/development.yml.enc config/credentials/test.yml.enc` was empty.
- CI workflow was not edited by this follow-up; it remains pre-existing dirty worktree content.
- Database migrations added: 0. Production/shared databases were not touched.
- Temporary scan reports and the extracted worktree snapshot were under ignored `tmp/`; they are not
  repository deliverables.
- No commit, push, or deployment was made.

The work order's zero-findings acceptance remains unmet for the owner-controlled and protected
findings listed above. Checks that passed are reported only for the commands and tree described
here; the current results do not imply a clean checkout or production verification.
