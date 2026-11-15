# Remove Unreachable Ceremony Code — Final Revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree already contained extensive uncommitted changes; `git status --porcelain=v1`
reported 977 changed or untracked paths before this record. The implementation inventory is in
[`2026-11-13-remove-unreachable-ceremony-code-Q7M2.md`](2026-11-13-remove-unreachable-ceremony-code-Q7M2.md);
post-reset verification and current-tree revalidations are in N4C7, R8K2 and Z8M6. This record
supersedes the earlier hold on the two sign-up contact guards described below. No commit, push or
deployment was made.

## Ownership and starting-list disposition

The owner decision is that Access executes authentication ceremonies and owns OP data; Governance
owns identity and credential records, RP-local state and the OIDC handoff boundary. The runtime
search over `app/`, `lib/`, `config/`, `db/`, `test/`, `src/` and `gait/` found no remaining
definitions, callers or serialized names for the removed starting-list classes/methods. The
`CoreRpBridge` module itself is the intentional exception and remains for active bridge behavior.
Earlier revalidations also checked dynamic-name lookup and route references.

| Starting item                                                        | Finding and disposition                                                                                                                                                                                                                                                          |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FlowSignIn` / `SignInFlow`                                          | No application caller. Local flow concerns, codecs, readers and ceremony-only consumers/tests were removed.                                                                                                                                                                      |
| `FlowSignUp`                                                         | No application caller. Local sign-up, admission and OTP ceremony code, routes, UI and exclusive tests were removed.                                                                                                                                                              |
| `OpaqueAdmissionStore`                                               | No application reader or writer. Its Valkey store and ceremony-only consumers/tests were removed.                                                                                                                                                                                |
| `AuthAdmissionBinding`                                               | Its former only reader was the deleted `SignFlow` duration constant. Both were removed; no live duration reader remains to receive the constant.                                                                                                                                 |
| `RefreshTokenShared` / `OidcConnectionRecord`                        | No application includer or caller. The concerns, unreachable session OIDC connection path and ID-token issuer were removed.                                                                                                                                                      |
| OP step-up result/grant decoders and result issuer                   | No Governance application caller. OP ceremony values, issuer and exclusive consumers/tests were removed. RP-owned state, transitions, audit/outbox, recovery and handoff remain.                                                                                                 |
| `CoreRpBridge#actor`, `#subject`, `#core?`, `core_actor_foreign_key` | No callers. The methods and attribute were removed. `CoreRpBridge` remains for active bridge behavior; its current includers are `CoreAppClientBridge` and `CoreOrgOperatorBridge` at `app/models/core_app_client_bridge.rb:25` and `app/models/core_org_operator_bridge.rb:25`. |

The current targeted search found no occurrence in executable code of the six removed legacy policy
classes or the removed contact guard classes. `CoreRpBridge` itself and its two live inclusions are
intentional. Remaining matches in dated evidence, archived plans/research, old migration history,
and historical fixtures preserve provenance rather than providing runtime callers.

## Additional candidate decisions and final delta

This pass removed six unreachable policies whose models and routes no longer exist:
`ClientOidcConnectionPolicy`, `OperatorOidcConnectionPolicy`, `ClientWebauthnCredentialPolicy`,
`OperatorWebauthnCredentialPolicy`, `ClientTimeBasedTotpCredentialPolicy` and
`OperatorTimeBasedTotpCredentialPolicy`. Their four exclusive WebAuthn/TOTP policy test files were
removed. Current Client/Operator passkey and TOTP credential policies and record-management paths
remain.

The earlier Q7M2 record provisionally kept `AppRegisteredContactDestinationGuard` and
`SignUpEmailPendingGuard` as owner-side data-protection candidates. Rechecking all runtime roots
found no application caller beyond those two classes calling each other; their tests and old
coordinator callers are absent. They only supported retired local sign-up/contact registration, so
both files were deleted. Historical delivery-limit and lock-order records retain their former source
references under historical/supersession context.

`PasskeyRegistrationOperation` and `Webauthn::Surface` remain. The operation currently has test and
static-invariant callers rather than a local ceremony route, but it is the single guarded owner-side
writer for Governance passkey records and their audit outboxes, enforcing owner identity,
registration limits and audit invariants; it is not a local ceremony controller or verifier.
Credential records, external-identity/source receipts, audit history, withdrawal lifecycle data, RP
state and the server-to-server lookup/revocation paths were retained. OP-dependent paths that still
lack Access APIs continue to fail closed with explicit unavailable errors/responses; they do not
fabricate empty results or run local fallback ceremonies. Focused coverage added/extended in
`test/integration/base_step_up_start_test.rb` verifies completion and cancellation return explicit
unavailable responses for APP and ORG without changing step-up state or revoking sessions (3 tests,
57 assertions passed).

The ceremony work did not alter database schema, structure dumps, tables, columns, indexes,
constraints or persisted rows. The earlier implementation removed only the unused
`db/migration_support/sign_in_flow_state_storage.rb` under `db/`; no current ceremony-only table or
readerless table was identified. RP state/audit and withdrawal-history tables remain owned. Other
database changes in this shared worktree belong to the separate DatabaseConsistency task and cannot
be attributed to this work order.

## Documentation status

`docs/security/step-up-operation-inventory.md` now labels the old matrices as pre-split history and
describes the retained RP handoff and fail-closed routes. `docs/security/step-up-mfa-status.md` no
longer describes local setup, enrollment or verification as current. Current ADR/backlog/spec
supersession notices and the retained/updated document inventory are detailed in Q7M2 and N4C7. The
lock-order inventory and telephone delivery-limit backlog retain old source references only as
historical snapshots. The old visitor/com diagrams remain archived; no active Mermaid diagram
describes Governance-local authentication ceremonies. Research, prior evidence and migration history
were not rewritten.

## Verification

The disposable test database reset is recorded in N4C7. Final runs used the explicit current
test-writer list from `config/ci.rb` (`test_primary_db`, `test_app_zenith_db`, `test_org_zenith_db`,
`test_app_setting_db`, `test_com_setting_db`, `test_org_setting_db`, `test_app_signal_db`,
`test_org_signal_db`, `test_avatar_db`, `test_chronicle_db`, `test_occurrence_db`, `test_queue_db`,
`test_storage_db`, `test_rp_base_app_db`, `test_rp_base_org_db`, `test_rp_tech_org_db`). The list
targets test-prefixed databases only.

| Command                                                                                            | Result                                                                                                                                  |
| -------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `RAILS_ENV=test bin/rails zeitwerk:check`                                                          | Passed: `All is good!`.                                                                                                                 |
| `RAILS_ENV=test bin/rails routes`                                                                  | Passed; 429 output lines.                                                                                                               |
| `bin/rubocop`                                                                                      | Passed: 2,817 files inspected, no offenses.                                                                                             |
| `bundle exec erb_lint --lint-all`                                                                  | Passed: 1,510 files, no errors.                                                                                                         |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                   | Passed: 0 warnings, 0 errors.                                                                                                           |
| `bun run check`                                                                                    | Passed format, lint, typecheck, dead-code and OpenAPI checks. Knip emitted its existing `.css` configuration hint.                      |
| `env -u COVERAGE POSTGRESQL_TEST_PREPARE_DATABASES=<the list above> RAILS_ENV=test bin/rails test` | Passed: 7,488 runs, 49,844 assertions, 0 failures, 0 errors, 0 skips.                                                                   |
| `COVERAGE=true POSTGRESQL_TEST_PREPARE_DATABASES=<the list above> RAILS_ENV=test bin/rails test`   | All 7,488 tests passed; process exited 2 only because global SimpleCov minima were not met.                                             |
| `RAILS_ENV=test bundle exec database_consistency`                                                  | Exit 1, `No configuration files were provided`, and the seven unrelated findings below. No checker exclusions/configuration were added. |
| `git diff --check`                                                                                 | Passed.                                                                                                                                 |

Final SimpleCov result: **90.27% line (30,182/33,435), 61.84% branch (3,498/5,656), and 85.19%
method (4,349/5,105)** against existing minima of 98%, 93% and 97%. The prior recorded coverage was
88.45% line, 59.57% branch and 81.09% method. Source/test inventory and the combined dirty worktree
changed between measurements, so the difference cannot be attributed solely to this cleanup.

The work-order baseline cites 7,657 tests; a separate older C8N4 record contains a 7,669-run full
suite. The final 7,488 runs are 169 below the stated baseline (181 below 7,669). The shared tree
already had extensive unrelated changes and tests were removed/added across earlier work, so an
exact per-test attribution is not available. The immediate pre-cleanup full run and the final run
both had 7,488 tests; assertion totals varied by a few assertions between parallel runs, while the
final normal and coverage runs agree at 49,844.

DatabaseConsistency still reports one unique-index/validator mismatch for
`OperatorChronicle.uniq_operator_chronicles_sign_flow_halted` and six NOT NULL/model-presence
mismatches: `Bureau.name`, `Bureau.title`, `Agent.title`, `Enterprise.name`, `Enterprise.title` and
`ClientPersona.title`. These belong to the original DatabaseConsistency remediation task.

`git diff --exit-code HEAD -- config/credentials config/ci.rb` passed. `.github/workflows/ci.yml`
remains modified in the shared worktree, as it was before this pass; it was not edited. No commit,
push or deployment was performed.

## Remaining limits

- Access's OP data query/revocation APIs are not yet available; retained Governance paths fail
  closed.
- The seven DatabaseConsistency findings remain for the separate database remediation task.
- Repository coverage minima remain unmet even though all 7,488 tests pass.
- Historical records still describe former ceremonies under explicit supersession/history context.
