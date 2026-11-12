# Local Surface Hard Reset

Status: implementing

Authority: owner-approved task dated 2026-11-10. The owner clarified that Auth/Visa URL settings
must be removed even though this disables Base/Tech OIDC sign-in and sign-out. Base and Tech RP
callback, Back-Channel Logout receiver, and OIDC-driven step-up callback routes are included in that
removal because they require the provider endpoint URLs or keys.

Scope clarification (2026-11-11): a later follow-up excludes `.github/**` from the completion audit;
no `.github` files are changed or counted toward this scope.

## Purpose and scope

Keep this Rails repository's Base `app` / `org` / `com` surfaces, Tech operator surface and
operator tools. Remove every other local route/controller surface and remove outbound Auth/Visa
OIDC dependencies. Remove runtime code and tests that have no remaining caller after that cut.

Do not drop databases, delete models or migrations, commit, or change external systems. Preserve
unrelated existing worktree changes. Base `com` and its corporate configuration remain because
Base `com` routes are intentionally kept.

## Acceptance

- AC-1: The route inventory is grouped by logical host constraint and includes every route and
  controller namespace, identifying each as owned or foreign/retired without printing resolved
  environment values.
- AC-2: Only Base, Tech and operator-tool local routes/controllers remain. Auth/Visa OIDC entry,
  callback, logout and remote-URL callers are removed; corresponding environment readers and
  editable environment definitions are removed.
- AC-3: Iterative dead-code removal leaves no newly unreferenced local services, values, jobs,
  policies, adapters or concerns. Models and migrations remain unchanged.
- AC-4: The report classifies every `*Record` target in `config/database.yml` as USED,
  ONLY-VIA-MODELS or UNUSED, with caller examples for models referenced outside models.
- AC-5: `bin/rails zeitwerk:check`, `bin/rails routes`, `bin/rubocop`,
  `bundle exec erb_lint --lint-all` and `bin/rails test` are run; change-caused failures are fixed
  and pre-existing failures are identified separately.
- AC-6: A dated evidence record includes the full source revision, actual route counts,
  deletions, removed environment-variable names, database/model classification and check results.

## Verification and limitations

Run the requested repository checks after implementation. Never print environment values. Do not
perform database drops or schema changes. If a read-only mount blocks an authorized source edit,
record the exact path and incomplete acceptance in the evidence and final report.

AC-2 remains incomplete for retired local host aliases in `.devcontainer/compose.yaml`. The
governance round-two prompt explicitly prohibited touching `.devcontainer/**`, and the file is also
on a read-only ZFS mount. Existing Compose worktree changes were preserved; no task-specific edits
were made there. `.github/**` is outside the clarified follow-up scope.

AC-5 remains incomplete: `bin/rails zeitwerk:check`, `bin/rails routes`, `bin/rubocop`,
`bundle exec erb_lint --lint-all` and `bun run check` pass. The latest `bin/rails test` run is red
(9,782 runs, 63,754 assertions, 219 failures, 48 errors, 0 skips). This follow-up corrected 28
stale Jump-return success expectations against the intentionally empty local return graph; no new failure or error IDs appeared, and one stale unauthenticated route assertion error was resolved. The failure/error identifiers
and classification limits are recorded in `evidence/2026-11-11-governance-round2-R2A7.md`. The
clean-HEAD suite was red, but a complete clean-HEAD per-test identifier set was not retained, so
the remaining failures cannot all be attributed individually.
