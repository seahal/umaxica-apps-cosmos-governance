# Remove Unreachable Ceremony Code — Latest Revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree was heavily modified before this pass. `git status --short` showed 1,002 paths
at capture. Results describe the combined dirty tree and cannot all be attributed to this work
order. No commit, push or deployment was made. No schema, migration, data, CI, or credential file
was changed in this pass.

This record extends the item-by-item audit and prior removals in
[`2026-11-13-remove-unreachable-ceremony-code-Q7M2.md`](2026-11-13-remove-unreachable-ceremony-code-Q7M2.md)
and incorporates the later revalidations through
[`2026-11-13-remove-unreachable-ceremony-code-C5P2.md`](2026-11-13-remove-unreachable-ceremony-code-C5P2.md).
The owner decision remains that Access runs OpenID Provider authentication ceremonies; Governance
retains identity and credential records, RP state, audit history and its relying-party boundary.

## Changes in this pass

- Removed `app/models/concerns/token_json_sanitizable.rb`. A case-sensitive and case-insensitive
  reference search across `app/`, `lib/`, `config/`, `db/`, `test/`, `src/` and `app/views/` found
  no include, constant lookup, serialized class name or other consumer. The concern only redacted
  fields from JSON serialization for retired refresh-token records; no current model uses it.
- Removed the unused `base_admission_surface_name` class methods from
  `app/controllers/base/app/application_controller.rb` and
  `app/controllers/base/org/application_controller.rb`. The full runtime-source search found no
  caller or dynamic reference. The empty singleton-class visibility blocks left by those method
  removals were removed too.
- Added `test/integration/base_access_authority_api_unavailable_test.rb`. It explicitly exercises 52
  remaining APP/ORG identity, Avatar, IAM and Support API method/path pairs that use the Access
  authority boundary. Each returns `503 application/problem+json`, the unavailable problem type,
  `Cache-Control: no-store`, and no redirect. Existing membership, switcher, dashboard identity, IAM
  grant-create, and tech-capability tests cover their additional routes.
- In a later coverage review, removed `BannerModel#actor` because both current includers override
  it, and the empty `PromotionalEmailUnsubscribeActions#edit` because both concrete controllers
  implement the real action. Their existing model and request tests remain. Added a focused
  lifecycle assertion for `EnforcementRecoveryCeremonyRecordable#revoke!` rather than deleting this
  security transition.

The existing `AvatarAuthorityApiEndpoint` implementation was not changed: it authenticates the
client assertion first and returns an explicit service-unavailable problem when Access authority is
unavailable. The server-to-server lookup and revocation behavior was not redesigned or removed.

## Audit results and retained code

The starting-list disposition and representative implementation/test deletions are recorded in Q7M2.
The current executable search for `FlowSignIn`, `FlowSignUp`, `OpaqueAdmissionStore`,
`AuthAdmissionBinding`, `RefreshTokenShared`, `OidcConnectionRecord`, the six retired credential and
OIDC policies, `OrgRegistrationPolicy`, `OrganizationInvitationPolicy`, `AdmissionCurfewValue`,
`base_admission_surface_name`, `SignUpEmailPendingGuard`, `AppRegisteredContactDestinationGuard` and
`TokenJsonSanitizable` returned no matches. A separate runtime/test search found no
`auth_state:admission`, `Namespaces.admission` or `ADMISSION =` reference.

`CoreRpBridge` remains because `app/models/core_app_client_bridge.rb` and
`app/models/core_org_operator_bridge.rb` include it for live bridge behavior. Its old `actor`,
`subject`, `core?` and `core_actor_foreign_key` API remains removed. The additional decisions from
C5P2 also remain in force: the six unreferenced OIDC/WebAuthn/TOTP policies,
`OrgRegistrationPolicy`, `OrganizationInvitationPolicy`, `AdmissionCurfewValue`, the admission
Valkey namespace and its test cleanup keys were removed; owner credential records, passkey/TOTP
management, audit writers, RP state and lifecycle history were retained.

Further candidates were reviewed as follows:

- APP/ORG verification start, completion and cancellation remain routed and return explicit
  unavailable responses while Access is unavailable; `test/integration/base_step_up_start_test.rb`
  verifies no new RP step-up state/audit record and no session revocation.
- Session listing/revocation methods remain explicit unavailable boundaries in
  `AuthenticationSessionRevoker`; the existing Client and Operator tests exercise the boundary.
- Passkey and TOTP credential records and their owner-side management remain because Governance owns
  those records. `PasskeyRegistrationOperation` remains the guarded owner-side record writer and
  audit boundary; it has tests/static-invariant uses but no local ceremony route.
- `CoreAppClientBridge` and `CoreOrgOperatorBridge` retain the two live `CoreRpBridge` inclusion
  paths. `OperatorTelephonePublicIdBackfillOperation` remains reachable from the documented
  maintenance rake tasks.
- `ClientContactAuditOutbox`'s audit-recording API remains because audit history is an owner
  contract. No table or column was removed based on a class-level reachability scan.
- No local social sign-in callback route remains. Avatar follow/block/mute routes are separate owner
  APIs and are included in the fail-closed API tests.

The database audit remains unchanged: no current ceremony-only table was identified for removal. RP
step-up state and audit tables, withdrawal lifecycle/history tables, credential records,
external-identity/source receipts, registration-completion records and Chronicle history remain. The
old visitor/COM diagrams are under `docs/mermaid/archive/visitor-com-retired/`; no active Mermaid
diagram describes the deleted local ceremony paths.

Current docs/ADRs already updated or marked superseded for the removed behavior are listed in Q7M2:
`adr/base-auth-ceremony-and-seven-rp-boundary.md`, `adr/passkey-identifier-first-sign-in.md`,
`adr/sign-up-flow-admission-binding-and-cardinality.md`, the authentication, OTP, passkey, TOTP,
WebAuthn and step-up docs under `docs/security/`, `docs/reference/identifier-conventions.md`,
`docs/checklists/identifier-contracts.md`, `docs/checklists/integrated-stack.md`, and the sign-flow,
sign-up, social-link and OP-mediated step-up backlog/spec records. Historical inventories and
archived plans/research were preserved. In particular,
`specs/op-mediated-step-up/contracts/lock-order-inventory.md` and
`research/2026-10-22-test-value-audit/inventory/rails-services-sign_up.md` contain dated references
to removed sources as historical evidence; they are not executable references.

## Verification

Tests were run only against the current `test_*` writer database catalog. No production, shared or
external database was changed.

| Command                                                                                                                                                                                                        | Result                                                                                                                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `RAILS_ENV=test bin/rails test test/integration/base_access_authority_api_unavailable_test.rb`                                                                                                                 | 2 tests, 312 assertions, 0 failures/errors/skips.                                                                                                                                                                                                                        |
| Focused unavailable-boundary group (`base_access_authority_api_unavailable`, `access_op_owner_api_unavailable`, `base_membership_directory_owner_unavailable`, `base_org_iam_owner_api`, `base_step_up_start`) | 9 tests, 515 assertions, 0 failures/errors/skips.                                                                                                                                                                                                                        |
| Focused banner/email-controller tests after the dead concern-method cleanup                                                                                                                                    | 28 tests, 94 assertions, 0 failures/errors/skips.                                                                                                                                                                                                                        |
| Focused recovery-ceremony lifecycle tests                                                                                                                                                                      | 2 tests, 11 assertions, 0 failures/errors/skips.                                                                                                                                                                                                                         |
| Final coverage-enabled full Rails suite after these edits                                                                                                                                                      | 7,499 tests, 50,194 assertions, 0 failures/errors/skips. Process exit 2 only because repository SimpleCov minimums are unmet: line 90.34% (30,163/33,388; min 98%), branch 61.89% (3,500/5,655; min 93%), method 85.52% (4,356/5,093; min 97%).                          |
| `RAILS_ENV=test bin/rails zeitwerk:check`                                                                                                                                                                      | Passed: `All is good!`.                                                                                                                                                                                                                                                  |
| `RAILS_ENV=test bin/rails routes`                                                                                                                                                                              | Passed; 429 output lines.                                                                                                                                                                                                                                                |
| `bin/rubocop`                                                                                                                                                                                                  | Passed; 2,817 Ruby files inspected, no offenses. Focused reruns of the edited files also passed.                                                                                                                                                                         |
| `bundle exec erb_lint --lint-all`                                                                                                                                                                              | Passed; 1,510 ERB files, no errors.                                                                                                                                                                                                                                      |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                                                                                                               | Passed; 0 warnings, 0 errors.                                                                                                                                                                                                                                            |
| `bun run check`                                                                                                                                                                                                | Passed format, lint, typecheck, dead-code and OpenAPI checks. Knip printed its existing `.css` configuration hint.                                                                                                                                                       |
| `git diff --check`                                                                                                                                                                                             | Passed.                                                                                                                                                                                                                                                                  |
| `git diff --exit-code HEAD -- config/credentials`                                                                                                                                                              | Passed; no credential paths changed.                                                                                                                                                                                                                                     |
| `RAILS_ENV=test bundle exec database_consistency`                                                                                                                                                              | Exit 1; no checker config was supplied and one existing finding remains: `UniqueIndexChecker fail OperatorChronicle uniq_operator_chronicles_sign_flow_halted index is unique in the database but does not have a uniqueness validator`. No checker exclusion was added. |

The previous recorded suite in C5P2 was 7,488 tests with coverage 90.27% line, 61.84% branch and
85.19% method. The latest current-tree result is 11 tests higher with slightly higher reported
coverage. These are measurements of a heavily modified shared tree, not a causal attribution to this
work order. The work-order baseline cites 7,657 tests; the current run is 158 lower. Extensive
existing changes and prior additions/removals prevent a reliable per-test reconciliation. The
SimpleCov exit is a coverage-threshold failure, not a test failure. The current public/protected
inventory and per-row status are recorded in
[`2026-11-13-coverage-completion-P7V4.md`](2026-11-13-coverage-completion-P7V4.md).

No `db/` path, `config/credentials/` path or `.github/` path was edited in this pass. No commit,
push or deployment was made.

## Remaining limits

- Access's OP data query/revocation APIs are not yet available; retained Governance callers continue
  to fail closed.
- DatabaseConsistency reports one expression/partial-index mismatch that the checker does not
  understand; changing valid uniqueness semantics to satisfy it would be incorrect.
- The Minitest line, branch and method coverage gates remain unmet; the full public/protected method
  reachability inventory remains open. The latest inventory has 144 uncovered rows, 135 no-location
  rows and 21 same-line rows; see P7V4.
- The full starting-list disposition, file removals, and historical-document treatment are in Q7M2
  and the subsequent evidence chain referenced above.
