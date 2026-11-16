# Remove Unreachable Ceremony Code

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Worktree: it was already heavily dirty at task start. At evidence capture, `git status --short`
showed 700 changed paths before this evidence file itself was added. Results below describe the
combined working tree; they cannot all be attributed to this work order. No commit or push was made.

## Decision and scope

The owner decision recorded in the work order and Access's OpenID Provider ownership ADR (decisions
14 and 17–19) establish Access as the owner of sign-in, sign-up, step-up, WebAuthn and social
authentication ceremonies. Governance keeps identity and credential records, credential management,
owner-side audit/history, RP-local step-up state and the OIDC handoff boundary. No production or
shared database was changed.

The database audit found no current ceremony-only table to remove. No migration, structure dump,
table, column, index, constraint or persisted row was changed. The only removed file under `db/` was
`db/migration_support/sign_in_flow_state_storage.rb`, unused migration support code. Current
structure dumps still contain the RP step-up state/audit tables and withdrawal ceremony/history
tables; both remain owned and used. Identity/credential records such as `ClientPasskey`,
`OperatorPasskey`, `ClientTotpCredential`, `ClientExternalIdentity`, registration-completion
records, and social source receipts remain. Flow-reference columns used by retained secret
issuance/claim and registration-completion records remain unchanged.

## Starting-list audit

Current application, library, configuration, route, view, frontend, database and test references
were searched, including dynamic constant lookup patterns and serialized/string references. A
test-only reference was not treated as an application caller.

| Starting item                                | Finding and disposition                                                                                                                                                                                                                                                                   |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FlowSignIn`, `SignInFlow`                   | No current application includer/caller. Removed the flow concerns and their binding codec and ceremony-only consumers/tests.                                                                                                                                                              |
| `FlowSignUp`                                 | No current application includer/caller. Removed the flow concern and ceremony-only admission/OTP components, consumers and tests.                                                                                                                                                         |
| `OpaqueAdmissionStore`                       | No current application reader or writer. Removed `app/services/valkey/auth_state/opaque_admission_store.rb`.                                                                                                                                                                              |
| `AuthAdmissionBinding`                       | Its only former Governance reader was the dead `SignFlow` duration constant. Both were removed; no duration consumer remains in Governance.                                                                                                                                               |
| `RefreshTokenShared`, `OidcConnectionRecord` | No current application caller. Removed those concerns and the now-unreachable session OIDC connection concern and ID-token issuer.                                                                                                                                                        |
| Step-up result/grant decode APIs and issuer  | No current Governance application caller for OP-issued ceremony results. Removed the identity ceremony grant/result/contract and result-issuer chain, OTP email challenge and ceremony-only consumers. RP-owned state, transitions, audit outboxes, dispatch recovery and handoff remain. |
| `CoreRpBridge#actor`, `#subject`, `#core?`   | No caller. Removed these methods and the write-only `core_actor_foreign_key` attribute. Kept `CoreRpBridge` because `CoreAppClientBridge` and `CoreOrgOperatorBridge` include it for the remaining bridge behavior.                                                                       |

Representative removed implementation paths include
`app/models/concerns/{auth_admission_binding, flow_sign_in,flow_sign_up,oidc_connection_record,refresh_token_shared,session_oidc_connection, sign_flow,sign_flow_status_backed,sign_in_flow,social_identifiable,step_up_email_challenge}.rb`,
`app/services/valkey/auth_state/opaque_admission_store.rb`, ceremony-only files under
`app/consumers/`, `app/values/identity_*_ceremony*`, OTP delivery/digest values and codecs,
`app/controllers/base/{app,org}/verification/setups_controller.rb`,
`app/resolvers/webauthn/relying_party_config_resolver.rb`,
`app/values/webauthn/relying_party_config.rb`, the local WebAuthn initializer, setup
pages/controllers and their `src/`/`gait/` implementations, plus corresponding ceremony-only tests,
fixtures and views. The related `config/initializers/` filter list and both locale bundles were also
cleaned of unreferenced `step_up_ceremony_result`, `step_up_ceremony_grant` and `sign_in_flow_id`
entries. The WebAuthn static invariant guard remains.

## Additional candidate audit

- Removed dead `Client` social/login helper methods and the unused `SocialIdentifiable` concern.
  `ClientExternalIdentity`, source receipts, ownership/audit records and historical Chronicle events
  remain because they store owner data/history. The `social_link` and `social_unlink` step-up scopes
  were removed; tests assert both scopes are absent for APP and ORG.
- Removed dead local OTP/TOTP ceremony delivery, challenge, resend, window-consumer, and local
  passkey registration/setup UI code. Kept credential models, management controllers/policies,
  enrollment limits, retention/revocation and owner-side audit paths.
- Removed dead ceremony-only `CoreRpBridge` methods, not the bridge model behavior.
- Remaining `sign_up_flow_ref` and `claim_sign_in_flow_ref` references are used by retained
  registration-completion and secret credential issuance/claim lifecycle records. They are not local
  ceremony tables and were not changed.
- Repository-wide remaining `social_link`/`social_unlink` hits are limited to the absence
  assertions, retained source-receipt association/model, and historical Chronicle fixtures/locales.

## Fail-closed OP dependencies

Governance entry points that still require Access OP authority fail explicitly. They do not
fabricate empty lists, issue local credentials, redirect as if successful, or mutate local step-up
state when the OP data/API is unavailable.

- `AuthenticationSessionRevoker` raises `AccessOpDataUnavailableError` for listing and revocation
  methods; `test/controllers/concerns/authentication/session_revoker_test.rb` covers all three
  methods for Client and Operator.
- APP/ORG verification start remains unavailable without OP authority. The integration observability
  test verifies 503, no new step-up state/audit event and no actor/session/token identifiers in
  logs.
- Avatar owner APIs and the tech-capability API return explicit 503 problem responses;
  `test/integration/access_op_owner_api_unavailable_test.rb` also verifies unauthenticated callers
  receive 401 and responses are no-store.
- Access-owned membership directory paths return service unavailable rather than a successful empty
  directory; covered by `test/integration/base_membership_directory_owner_unavailable_test.rb`.
- Policy, model and query boundaries that require Access authority raise the explicit unavailable
  error and have focused tests, including `test/policies/access_op_requirement_unavailable_test.rb`,
  `test/models/access_op_model_boundary_test.rb` and
  `test/queries/tech_capability_check_query_test.rb`.

## Documentation retained or updated

Current docs/ADRs describing retired Governance-local ceremonies were updated with the Access
ownership boundary or marked superseded, including:

- `adr/base-auth-ceremony-and-seven-rp-boundary.md`, `adr/passkey-identifier-first-sign-in.md`,
  `adr/sign-up-flow-admission-binding-and-cardinality.md`;
- `docs/security/authentication-capacity-admission.md`, `otp-audit.md`, `passkeys.md`,
  `passkey-lifecycle-and-audit.md`, `step-up-mfa-status.md`, `step-up-operation-inventory.md`,
- `webauthn-architecture.md`, `webauthn-rp-id-origin-boundary.md`,
  `webauthn-security-invariants.md`, `authentication-assurance-levels.md`,
  `org-emergency-access.md`, `app-secret.md` and `identifier-encryption-inventory.md`;
- `docs/reference/identifier-conventions.md` and the `docs/checklists/identifier-contracts.md` and
  `docs/checklists/integrated-stack.md` sections whose Governance-local transaction/grant and
  cross-surface sign-in criteria were superseded;
- the sign-flow termination backlog, bootstrap/unification backlog plans, social-link hands-on
  review backlog, and OP-mediated step-up contracts/specification. The social-link hands-on review
  is marked superseded for Governance with the Access owner/evidence reference.

The session-management, authorization and preference-lifecycle checklists retain their current RP,
authorization and credential-management requirements; they do not claim Governance executes the
retired provider ceremonies. Historical research and audit inventories, old migration history, prior
evidence and archived diagrams were preserved as historical material. Retired visitor/com diagrams
remain under `docs/mermaid/archive/visitor-com-retired/`; no active Mermaid diagram still describes
the removed Governance ceremony paths. `specs/test-coverage-completion/spec.md` labels prior
coverage numbers as historical and records the new result.

## TDD and verification

The social-link step-up scope test was run before removing the obsolete scopes: 10 tests, 405
assertions, one expected failure proving the stale scopes were still present. After the production
change, the related step-up suite passed: 109 tests, 1,025 assertions, zero failures. The static
WebAuthn invariant guard was restored and remains runnable; its focused run passed 11 tests and 102
assertions. After the final dead `CoreRpBridge` attribute cleanup, focused tests passed 26 tests and
456 assertions.

Final full test run used the current writer test database list explicitly because `.env` still named
retired databases. A plain `bin/rails test` stopped in test database safety before tests began,
reporting the unverified retired names; it did not run migrations. The explicit current-list run
passed:

- `POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_com_setting_db,test_org_setting_db,test_app_signal_db,test_org_signal_db,test_avatar_db,test_chronicle_db,test_occurrence_db,test_queue_db,test_storage_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db bin/rails test`:
  7,490 runs, 49,487 assertions, 0 failures, 0 errors, 0 skips. The current Rails test safety
  catalog verified test-prefixed databases on the configured isolated PostgreSQL test host. Its
  required writer list includes `test_queue_db`; no Queue schema/configuration or application file
  was edited.
- After the last locale/filter-only cleanup, focused tests for locale parity/bundle integrity,
  parameter logging, WebAuthn invariant guard, step-up scopes and session revocation passed: 43
  runs, 668 assertions, 0 failures, 0 errors, 0 skips.
- Before the final locale/filter-only cleanup, the full `COVERAGE=true` run also executed all 7,490
  tests with 0 test failures/errors/skips, but the process exited 2 because repository SimpleCov
  thresholds were not met: line 88.45% (29,132 / 32,933, minimum 98%), branch 59.57% (3,451 / 5,793,
  minimum 93%), method 81.09% (4,237 / 5,225, minimum 97%).
- The work order cites 7,657 baseline tests; a later pre-change coverage record in
  `specs/test-coverage-completion/spec.md` records 7,669 (the evidence has two runs differing by
  12). Current 7,490 is 167 below the cited count and 179 below the later run, consistent with
  deleting unreachable ceremony-only test families. Exact per-test attribution is not possible
  because the worktree already contained extensive unrelated changes and the source/test denominator
  changed.
- `bin/rails zeitwerk:check`: passed. `bin/rails routes`: passed, 631 routes.
- `bin/rubocop`: 2,828 files inspected, no offenses. The final changed initializer was also checked
  directly after its cleanup.
- `bundle exec erb_lint --lint-all`: 1,201 files, no errors.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: passed, zero warnings/errors.
- `bun run check`: passed format, lint, typecheck, dead-code and OpenAPI checks.
- `git diff --check`: passed after final edits.
- `RAILS_ENV=test bundle exec database_consistency`: not clean; the command exited 1 with “No
  configuration files were provided” and seven findings. No `.database_consistency.yml` or checker
  exclusion was added. Findings were one `OperatorChronicle` unique-index/model-validation mismatch
  and six presence mismatches: `Bureau.name`, `Bureau.title`, `Agent.title`, `Enterprise.name`,
  `Enterprise.title`, and `ClientPersona.title`. This work order forbids schema changes; these
  remain for the database remediation task.

`config/credentials/` is unchanged. `config/ci.rb` has no diff from HEAD, and the required
`test/unit/security/webauthn_invariants_test.rb` static guard remains present.
`.github/workflows/ci.yml` was already dirty in the shared worktree and was not edited as part of
this work order. No CI/CD configuration change was made.

## Remaining limits

- Seven DatabaseConsistency findings remain as listed above; no schema was altered to silence them.
- SimpleCov thresholds remain unmet even though all Minitest tests pass.
- Historical documents, migrations and audit artifacts intentionally retain old names and behavior
  as historical evidence; current application code no longer defines or calls the removed ceremony
  classes. The current source grep's remaining social and flow-reference hits are documented above.
- All test counts and suite results reflect a heavily modified worktree, not a clean checkout.
