# Base Org Sign Entry and Shared RP Concerns

Date: 2026-11-14  
Repository revision: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Worktree: already contained extensive uncommitted work before this item; the final suite ran against
that combined tree. No commit or push was made.

## Delivered

- Restored Base Org's own sign entry, callback, interruption, sign-out, completion, and Back-Channel
  Logout routes using the existing `rp_base_org` cell. Base Org remains without public sign-up.
- Extracted shared relying-party behavior into realm-neutral concerns. The concerns require their
  including controller to provide the client, realm/resource, logging surface, issuer/JWKS,
  cell/record/session, and route hooks they need. The Base App and Base Org controllers supply those
  values explicitly.
- Added the Org RP client link to account navigation, restored the `visa_staff` host family from the
  existing environment-variable names `PUBLIC_VISA_STAFF_URL` and `PRIVATE_VISA_STAFF_URL`, and
  added the Visa Org origin to form-action policy. No environment values were printed.
- Kept App and Org client, state, callback, cookie, and RP database boundaries separate. Updated
  route, security-invariant, preference-email chrome, and cross-realm tests. The Tech controller was
  not changed; its existing cross-RP test now expects Base Org's same-host sign-entry refusal after
  a Tech token is rejected there.
- Updated current README, architecture, operations, security, UI inventory, the session-management
  checklist, session diagrams, transition inventories, and write-allowlist documentation. The UI
  inventory now records 180 Base App routes, 191 Base Org routes, and 528 total routes.
- No database schema or migration, CI workflow, credentials file, or deployed system was changed.
  The required host-family and CSP source configuration were updated.

## TDD and verification

Red runs were recorded during the staged implementation: the initial Org route/identity suite had 22
runs / 50 assertions / 4 failures / 12 errors; the Visa-origin check had 4 / 11 / 1 failure; and the
ID Token contract check had 4 / 22 / 1 error. The failures exposed missing routes, realm binding,
and expected refusal behavior before their corresponding implementations were completed.

Green regressions recorded after implementation:

- Base App safety suite: 44 runs / 320 assertions / 0 failures / 0 errors.
- Base Org core suite: 47 runs / 259 assertions / 0 failures / 0 errors.
- Shared Base App/Base Org RP suite: 81 runs / 583 assertions / 0 failures / 0 errors.
- Final route, chrome, refusal, cross-realm, and static-contract focused suite: 89 runs / 733
  assertions / 0 failures / 0 errors / 0 skips.
- Final Base App/Base Org RP callback, sign-entry, sign-out, and realm-isolation regression: 25 runs
  / 289 assertions / 0 failures / 0 errors / 0 skips.
- `bin/rails test --seed 50260`: 7,596 runs / 50,936 assertions / 13 failures / 0 errors / 0 skips.
  All 13 failures were in the explicitly out-of-scope Step-up or its verification boundary: Base
  App/Org Step-up start and evidence tests, Step-up observability, Base Shared RP selection, and the
  Org lifecycle information test. The Base Org withdrawal information request is redirected to
  verification when its local Step-up evidence is not accepted; Step-up implementation and its
  assertions were left unchanged.
- A default-seed full-suite run (seed 49866) had 7,596 runs / 50,874 assertions / 25 failures / 0
  errors. It also had order-sensitive Preference CSRF failures; the standalone Preference CSRF file
  passed 12 runs / 36 assertions. Re-running with seed 50260 removed those failures. Neither run is
  described as a fully green suite.

Checks:

- `bin/rails zeitwerk:check`: passed (`All is good!`).
- `bin/rails routes`: passed; inventory counts are recorded above.
- Full `bin/rubocop`: passed, 2,872 files, zero offenses. The final changed Tech test also passed
  `bin/rubocop` individually.
- `bundle exec erb_lint --lint-all`: passed, no ERB errors.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: passed, zero warnings.
- `git diff --check`: passed.
- `bundle exec database_consistency`: still reports the single previously recorded finding
  `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`; no consistency configuration or
  exclusion was added.
- `bun run check`: did not pass because the pre-existing untracked
  `gait/features/sign_out/sign_out_confirmation.test.tsx` fails the repository format check. That
  user-owned file was not edited. `bun run typecheck:verify`, `bun run deadcode`,
  `bun run openapi:lint`, and `bun run openapi:verify` passed; lint/typecheck also reported the same
  untracked file.

## Decisions and limits

- The Org sign-in label reuses the shared sign-in label because no Org-specific public sign-up label
  is required.
- The configured `visa_staff` host family was present by name in the development/production
  environment configuration; host values were not printed. No browser-level or external Access/Jump
  end-to-end verification was performed. The Visa Org authorize endpoint's previously observed 503
  remains an Access-owned item.
- Step-up, Tech Org runtime behavior, and ceremonies remain outside this work order. The only
  Tech-related edit is the cross-realm test expectation described above.
- The full Rails suite is not reported as passing because the 13 Step-up-boundary failures remain.
  The focused Base App/Base Org RP suites passed.
- `config/credentials` has no diff. A pre-existing dirty `.github/workflows/ci.yml` was left
  untouched; no CI change was made.
