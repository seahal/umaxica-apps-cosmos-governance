# Remove Unreachable Ceremony Code — Current-Tree Revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Branch: `feature`

Before this record, 953 changed or untracked paths were present in the shared worktree. The ceremony
implementation and detailed deletion inventory predate this revalidation and are recorded in
[`2026-11-13-remove-unreachable-ceremony-code-Q7M2.md`](2026-11-13-remove-unreachable-ceremony-code-Q7M2.md).
No commit, push or deployment was made. The only edits in this revalidation were status notes in the
documents listed below. No credential, schema, structure dump, route or CI workflow was edited.
`config/credentials/` has no worktree changes. `.github/workflows/ci.yml` remains pre-existing and
modified in the shared worktree; it was not changed here.

## Owner decision and current-tree search

The accepted owner decision is unchanged: Access runs all authentication ceremonies; Governance owns
identity and credential records, RP-local state and the OIDC handoff boundary, but runs no local
authentication ceremony. The current search checked `app/`, `lib/`, `config/` (including routes,
locales, initializers and YAML), `db/`, `test/`, `src/` and `gait/` for the removed names. No
removed symbol occurs in those current code or configuration paths. General `constantize`,
`const_get` and dynamic dispatch remain elsewhere, but none names a removed symbol.
`bin/rails routes` succeeded with 429 output lines; the retired local verification-setup, email,
passkey, TOTP, social and emergency sign-in route patterns are absent.

| Starting item                                                        | Current-tree finding and disposition                                                                                                                                                                                                                                   |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FlowSignIn` / `SignInFlow`                                          | No application caller or dynamic-name reference. The local flow concern, status concern, flow codec and ceremony-only readers/tests were removed.                                                                                                                      |
| `FlowSignUp`                                                         | No application caller or dynamic-name reference. The local concern and admission/OTP ceremony-only code and tests were removed.                                                                                                                                        |
| `OpaqueAdmissionStore`                                               | No current reader or writer. The Valkey store and its ceremony-only consumers/tests were removed.                                                                                                                                                                      |
| `AuthAdmissionBinding`                                               | No current reader. The former `SignFlow` duration reader was also removed; no constant was moved because no live reader remains.                                                                                                                                       |
| `RefreshTokenShared` / `OidcConnectionRecord`                        | No current application caller. Both concerns, the now-unreachable session OIDC connection concern and ID-token issuer were removed.                                                                                                                                    |
| OP step-up grant/result decode APIs and result issuer                | No Governance caller. Local OP ceremony grants, results, contracts, issuer, result consumers and ceremony-only tests were removed. RP-side start state, audit, dispatch recovery and OIDC handoff remain.                                                              |
| `CoreRpBridge#actor`, `#subject`, `#core?`, `core_actor_foreign_key` | None of the methods or the attribute remains. `CoreRpBridge` remains because `CoreAppClientBridge` and `CoreOrgOperatorBridge` include it at `app/models/core_app_client_bridge.rb:25` and `app/models/core_org_operator_bridge.rb:25` for still-used bridge behavior. |

The current grep still finds these names in old ADRs, superseded backlog/spec text, dated evidence,
historical research, archived plans and the retired visitor/com diagram archive. Those are
provenance, not executable callers. Remaining `sign_up_flow_ref` and `claim_sign_in_flow_ref`
columns and readers belong to retained registration-completion and Secret issuance/claim records;
they are not local flow objects. The same rule applies to retained identity, credential, source
receipt and audit records.

## Work retained from the implementation record

The implementation in Q7M2 removed the following unreachable groups and their exclusive tests,
fixtures, route entries, frontend callers and localization/configuration references:

- Flow and admission concerns under `app/models/concerns/`, including sign-in, sign-up, admission
  binding, refresh-token sharing and OIDC connection concerns;
- the opaque admission store, OP result issuer, OP ceremony grant/result value objects and result
  consumers;
- local OTP/TOTP delivery and challenge code, local WebAuthn setup and ceremony UI, and social
  authentication callback/result code;
- setup controllers/routes/pages and ceremony-only tests, including the removed WebAuthn and OTP
  test families;
- unused `db/migration_support/sign_in_flow_state_storage.rb`.

No database table, column, index, constraint, schema dump or persisted row was removed.
`git diff --name-only -- db` contains only the unused migration-support file above. The prior schema
audit found no ceremony-only table to drop. Registration-completion, Secret
credential/issuance/outbox, RP step-up state/audit, withdrawal history and credential data remain
owned records. No newly readerless table was identified in this revalidation.

Other candidate families were rechecked against Q7M2 and the current ownership boundary. Local
sign-in/sign-up, OTP/TOTP, WebAuthn enrollment UI, social callback and OP-result-consumer code with
no application caller was removed. Client/Operator passkeys, TOTP credentials, external identity
records, source receipts, registration completions, retention/revocation and owner-side audit remain
because they store or manage Governance-owned facts. Withdrawal and enforcement-recovery flows
remain business lifecycle records, not local OP authentication ceremonies. Server-to-server lookup
and revocation paths were not changed; retained OP-dependent entry points still fail closed as
recorded in Q7M2.

## Documentation status

This revalidation corrected the remaining current-reference gaps:

- [`adr/app-secret-phase1-rebuild.md`](../adr/app-secret-phase1-rebuild.md) now distinguishes the
  retained Governance credential lifecycle contract from its pre-split local Secret sign-in and
  Ticket/`SignInFlow` descriptions.
- [`plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md`](../plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md)
  is marked superseded for Governance; it remains historical context, not implementation authority.
- [`docs/reference/identifier-conventions.md`](../docs/reference/identifier-conventions.md) no
  longer says the removed local ceremony model classes remain pending cleanup; it records that
  schema/records were retained for separate owner-directed review.

Existing supersession notices remain in `adr/idp-flow-lifecycle-vocabulary.md`,
`adr/idp-flow-state-machine-lifecycle.md`, `adr/realm-separated-identifiers-and-dead-history.md`,
`adr/root-login-establishment-boundary.md`, `adr/sign-residual-idp-surface-retirement.md`,
`adr/sign-up-flow-admission-binding-and-cardinality.md`, `docs/security/session-limit.md`,
`docs/security/org-emergency-access.md`, `specs/op-mediated-step-up/spec.md`,
`plans/backlog/idp-flow-state-machine-unification.md`, and
`plans/backlog/2026-11-06-selector-state-machine-connection.md`. These records identify the retired
Governance behavior as historical or superseded. Dated evidence and research remain historical and
were not rewritten. No active Mermaid diagram describes a local Governance authentication ceremony;
the old visitor/com diagram remains under `docs/mermaid/archive/`.

## Database reset and verification

The safety check derived 15 non-replica writer databases from the current Rails test configuration.
Only `RAILS_ENV=test` was used for drop, create, prepare and test. The development, production and
shared databases were not targeted. No schema source was changed, and no Solid Queue source or
schema definition was edited.

| Command                                                                                                              | Result                                                                                                            |
| -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `RAILS_ENV=test bin/rails db:drop` with the derived `POSTGRESQL_TEST_PREPARE_DATABASES` writer list                  | Passed                                                                                                            |
| `RAILS_ENV=test bin/rails db:create` with the same list                                                              | Passed                                                                                                            |
| `RAILS_ENV=test bin/rails db:test:prepare` with the same list                                                        | Passed                                                                                                            |
| `RAILS_ENV=test bin/rails zeitwerk:check`                                                                            | Passed: `All is good!`                                                                                            |
| `RAILS_ENV=test bin/rails routes`                                                                                    | Passed; 429 output lines; retired local ceremony route patterns absent                                            |
| `bin/rubocop --fail-level convention --format simple`                                                                | Passed: 2,824 files, 0 offenses                                                                                   |
| `bundle exec erb_lint --lint-all`                                                                                    | Passed: 1,201 files, 0 errors                                                                                     |
| `RAILS_ENV=test bundle exec database_consistency`                                                                    | Exit 1 with the same 7 findings listed in the CI-static evidence; no checker configuration or exclusion was added |
| `bun run check`                                                                                                      | Passed format, lint, typecheck, dead-code and OpenAPI checks                                                      |
| `env -u COVERAGE RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=<derived current test writer list> bin/rails test` | Passed: 7,505 runs / 49,807 assertions / 0 failures / 0 errors / 0 skips                                          |
| `COVERAGE=true RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=<derived current test writer list> bin/rails test`   | All tests passed; SimpleCov exit 2 because configured coverage thresholds were not met (see below)                |
| `git diff --check`                                                                                                   | Passed                                                                                                            |

Coverage-enabled run: line 89.92% (30,148 / 33,525; minimum 98%), branch 61.43% (3,485 / 5,673;
minimum 93%), method 83.91% (4,300 / 5,124; minimum 97%). All 7,505 tests passed with no skips; the
exit 2 was solely SimpleCov's threshold failure. The preceding post-removal coverage record reported
88.45% line, 59.57% branch and 81.09% method. These measurements cover the combined dirty worktree
and later test additions; they do not prove the differences were caused by ceremony removal.

The work-order baseline was 7,657 runs in C8N4. Q7M2 recorded 7,490 after the ceremony test families
were removed (167 below that baseline); the current run is 7,505 (152 below the baseline and 15
above Q7M2). The broad decrease follows the removed unreachable ceremony test families. The exact
15-test net change since Q7M2 cannot be assigned to individual later edits because the shared
worktree already contained extensive changes and no matching test-inventory snapshot was retained.
There were no failing tests to classify as pre-existing or change-caused.

## Final status

- Unreachable Governance ceremony code was already removed; current code/config/DB/test/frontend
  searches confirm no starting-list symbol or caller remains.
- Governance-owned identity and credential records, RP-local state, withdrawal history and audited
  lifecycle paths remain. No schema or persisted data was dropped.
- Historical documents are retained only with explicit supersession/historical context; three
  documents were clarified in this revalidation.
- The full post-reset Rails suite passes. Coverage thresholds remain below configured minima, and
  the seven unrelated DatabaseConsistency findings remain documented in the CI-static evidence.
- Credentials are unchanged; no CI file, commit or push was changed or created.
