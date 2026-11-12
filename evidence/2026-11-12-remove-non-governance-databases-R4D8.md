# Remove non-Governance databases — implementation in progress

## Latest continuation checkpoint

- The final ownership/issuer retirement regression batch completed with 118 tests, 4,745 assertions, zero failures, errors or skips. Its first run had one invalid signed fixture; the corrected fixture includes the required authentication context and positive verification controls.
- The latest complete Rails suite before that retirement had 7,647 tests, 50,778 assertions, 16 failures, zero errors or skips. The subsequent focused batch verified the ownership cleanup; the complete suite has not been rerun after it.
- Original consistency work resumed. The current Red baseline for receipt/rotation/reservation changes is 31 tests, 82 assertions, 13 failures; no Green result is claimed. The independent audit-outbox Red baseline is 5 tests, 30 assertions, 4 failures. These test additions remain pending implementation and verification.
- A reviewable proposal for 98 additional NOT VALID foreign keys is at `specs/governance-database-consistency/remaining-foreign-key-validation.md`. No migration has been applied for this proposal. The earlier approval concerned 42 different constraints.
- `.github` remains mounted read-only; `patches/remove-non-governance-workflow-databases.patch` remains unapplied. This prevents full removal acceptance.
- The worktree remains heavily dirty and includes earlier work. No existing physical database was dropped during this removal phase.

## Current recovery checkpoint (2026-11-12)

Status: Governance source removal and regression recovery are complete in the worktree. Acceptance is incomplete because the read-only `.github` mount prevents the required workflow database-list edit.

- Earlier removal-recovery checkpoint, superseded by the passed final run below: `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test` — **7,653 tests, 49,303 assertions, 67 failures, 104 errors, zero skips**. Those 171 unsuccessful outcomes drove the recorded controller, Model, service and integration recovery; the final state is not represented by this historical count.
- Fresh isolated development `db:prepare` passed for 15 schema-owning retained stores (1,128 migrations per environment; Rails also prepared the isolated test configuration). Fresh isolated test `db:prepare` passed independently for 15 stores and 1,128 migrations. Queue tasks were disabled only in this temporary reconstruction configuration to avoid modifying the excluded Queue database; normal checker configuration still loads it. No existing/shared database was dropped or rebuilt. The first development seed attempt failed on removed OP catalog references; those exclusive seed blocks were removed before the successful fresh run.
- Frozen-file audit after reconstruction: **1,694 surviving migration/schema/document files unchanged**. Shared executable `db/seeds.rb` is a separately recorded authorized consumer cleanup, not a schema edit.
- Read-only PostgreSQL metadata audit of the 15 fresh stores: 523 user tables, 571 foreign keys, no missing primary keys, no non-bigint primary keys, no invalid indexes. **98 foreign keys remain NOT VALID**, belonging to Occurrence (63), Chronicle (19), ORG Setting (9), APP Setting (5), APP Signal (1), ORG Signal (1). This is an original consistency-task finding; their schemas remain unchanged during removal.
- Removal-task checkpoint standard `RAILS_ENV=test bundle exec database_consistency`: exit 1, **35 retained-database failures**, no reported Solid Queue failures. This is an intermediate historical count, superseded by the final checker run recorded below.
- Root crypto/browser/preference/lifecycle recovery: **72 tests, 330 assertions, zero failures/errors/skips**. The first rerun exposed two fixture Cookie-header overwrites of the anonymous preference cookie jar and one missing explicit external token identifier; all were corrected without fabricating OP issuance. The ORG closing-account gate now passes HTML redirect, JSON refusal, selector-write refusal and reserved-account rejection tests.
- Model/policy/API/RI/OpenAPI/database-path recovery: **89 tests, 448 assertions, zero failures/errors/skips**. Static architecture baseline: **3 tests, 910 assertions, zero failures/errors/skips**; only measured zero-offense entries removed, no exclusions added. Runtime deleted-constant scans: 488 removed definitions, 2,815 runtime files and 1,210 test files, zero executable consumers; deleted fixture/require dependencies zero.
- Service/job/operation regression recovery rerun: **115 tests, 963 assertions, zero failures/errors/skips**. It retains local legal-hold/privacy-blocked occurrences, independent Secret audit delivery and committed Governance anonymization effects while asserting explicit missing-Access failure. First recovery attempt had 5 failures/2 errors; those were corrected and the rerun completed.
- Final-stage `RAILS_ENV=test bin/rails zeitwerk:check`: exit 0, all eager loading succeeds.
- An intermediate static checkpoint had ERB lint **1,203 files, exit 0**, Brakeman **zero errors/security warnings, exit 0**, and 28 Ruby lint offenses. The final full Ruby lint now passes, as recorded below.
- An intermediate root preference/API/Turnstile batch passed 70 tests / 651 assertions, and an earlier frontend `bun run check` passed. These are historical scoped results; current full results are recorded below.
- `.github` remains mounted read-only. The exact workflow database-list patch is prepared at `patches/remove-non-governance-workflow-databases.patch`; patch validation passed, application failed with `Read-only file system`. This acceptance item remains blocked by the environment, despite the owner's authorization to make it writable. No mount or service bypass was attempted.


The full-suite review found an ORG lifecycle disagreement: the canonical resolver rejects closing Operators while the existing invariant requires a redirect to the ORG withdrawal page. The ORG controller includes the gate concern but did not register its callback. The implemented reconciliation admits only non-deactivated, non-reserved closing Operators to an explicit withdrawal gate **before actor selection, MFA, verification or controller actions**. Only the ORG withdrawal display is allowlisted, retaining its own verification/authorization. Added integration assertions cover protected JSON refusal, rejected selector writes and reserved-account rejection. The focused 72-test recovery batch verifies this unit; the original redirect failure was recorded by the full suite. Anonymous Home tests now assert the accepted 2026-10-25 same-path region canonicalization and subsequent Home rendering.

## Database ownership classification after the owner decision

Repository: Governance only. The owner's 2026-11-12 explicit retained/deleted inventory takes
precedence over older consolidation/authority documents; obsolete connection names are not treated
as current physical-database names.

| Connection | Classification in Governance | Basis / disposition |
| --- | --- | --- |
| primary | KEEP | Explicit retained inventory; application infrastructure |
| storage | KEEP | Explicit retained reservation; fresh database has no user tables |
| chronicle | KEEP | Governance audit ownership |
| app_zenith | KEEP | Accounts, credentials, profiles and related APP identity state |
| org_zenith | KEEP | Operators, organizations, roles and related ORG identity state |
| avatar | KEEP | Governance avatar authority |
| app_setting | KEEP | Explicit retained APP browser settings |
| org_setting | KEEP | Explicit retained ORG browser settings |
| com_setting | KEEP | Explicit retained COM browser settings |
| app_signal | KEEP | Explicit retained APP signal authority |
| org_signal | KEEP | Explicit retained ORG signal authority |
| occurrence | KEEP | Explicit retained occurrence authority |
| rp_base_app | KEEP | Governance's own APP relying-party state |
| rp_base_org | KEEP | Governance's own ORG relying-party state |
| rp_tech_org | KEEP | Governance's own Tech relying-party state |
| queue | EXCLUDED | Solid Queue; no schema/configuration edits |
| op_base_app, op_base_org | RETIRE (connection); Access responsibility | Governance OP consumers removed; no physical drop/data transfer claimed |
| publishing | RETIRE (connection); Press responsibility | Governance content consumers removed; no physical drop/data transfer claimed |
| search | RETIRE (connection) | Empty reservation explicitly removed |
| rp_core_app, rp_warp_app, rp_palm_app, rp_core_org, rp_warp_org, rp_edit_org | RETIRE (connections); service responsibilities | Foreign RP cells removed from Governance; no physical drops claimed |

Replicas follow their owning writer's disposition. Current configurations contain 16 writers and
30 total entries in each environment. Legacy `principal`/`publisher` references in historical
material do not establish additional live Governance databases. Retained `app_principals_migrate`
and `org_principals_migrate` are migration paths owned by Zenith, not separate live connections.

## Revision and scope

HEAD: `43db4906742db2fb13b238c9ccde378e4e1583b4`.

The worktree already contained approximately 3,500 uncommitted changes. Those changes affect execution and remain preserved. The original database-consistency improvement task is paused until this removal task is complete.

Removed ownership: OP APP/ORG belongs to Access; Publishing belongs to Press; Search is empty; Core/Warp/Palm/Edit RP cells belong to their services. No physical database was dropped. All surviving database schemas and migration sources are frozen for this task. Necessary surviving Model association cleanup was explicitly authorized by the owner.

## Observed verification (intermediate)

- `RAILS_ENV=test bin/rails zeitwerk:check`: passed after obsolete Publishing helper removal. Concurrent implementation continues, so final verification remains required.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test test/resolvers/step_up_evidence_verifier_test.rb test/resolvers/step_up_evidence_resolver_test.rb test/queries/tech_capability_check_query_test.rb test/controllers/concerns/browser_rp_authentication_test.rb`: 12 tests, 25 assertions, zero failures/errors/skips.
- `bundle exec erb_lint --lint-all`: 1,207 files; passed.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: zero errors/security warnings.
- `bun run check`: passed earlier in this removal cycle; frontend deletions require a final rerun.
- `bin/rubocop`: initial full run failed with 51 offenses, including changed lines and pre-existing unfinished database-consistency tests. Scoped fixes continue; full success is not claimed.
- `bin/rails test`: first two attempts stopped during loading at obsolete OP constants in mixed tests. Full-suite success is not claimed.
- SHA-256 comparison against the removal baseline: 1,695 protected surviving schema/migration/document files unchanged. The exclusive Publishing schema helper is an explicitly authorized deletion.

The inherited process environment still listed deleted test databases. The safety guard correctly rejected it. Verification unsets only `POSTGRESQL_TEST_PREPARE_DATABASES` so Dotenv reads the corrected explicit checked-in list of 16 writer databases; no safety guard was disabled.

## Additional intermediate results

- `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails db:prepare`: exit 0.
- Selector/switcher service regression: 6 tests, 22 assertions, zero failures/errors/skips. Both realm selection tests now use real local RP sessions and retain their authorization and persistence assertions.
- Retained Model/contact/storage/RP regression batch: 365 tests, 1,652 assertions, zero failures/errors/skips (agent execution). Two unfinished identifier-rotation uniqueness tests from the paused task remain outside that batch and are not represented as passing.
- External signed-token fixture integration: 3 tests, 21 assertions, zero failures/errors/skips. Both realm canonical-actor resolution and invalid-session rejection are exercised without OP database issuance.
- Policy and anonymous private-image boundary tests: 8 tests, 126 assertions, zero failures/errors/skips.
- Development migration status shows 14 unapplied migrations from the paused consistency task. Standard development `db:prepare` has not been run because it would change surviving schemas during this removal phase.
- First combined API/SMS/static-guard run: 33 tests, 207 assertions, zero failures, two errors. One is a removed-source static assertion; one is invalid ORG test fixture data before the SMS job runs. Corrections and reruns are pending; this batch is not a success.

## Shared seed cleanup and intentional infrastructure references

`db/seeds.rb` still required deleted OP migration files and seeded OP reference catalogs. Only those OP-only blocks were removed; every surviving catalog/sample-data writer remains unchanged. This is shared seed-code cleanup, not a schema change. The original conservative protected-file manifest included this executable seed file; future comparisons distinguish this authorized code edit from frozen migrations/dumps. `bin/rubocop db/seeds.rb` passes.

Terraform still declares Publishing object-storage buckets in development/staging-development configuration. Those are external resource ownership/state concerns rather than PostgreSQL database consumers; no Terraform apply, destroy or storage deletion was attempted. They are listed for the Press/infrastructure ownership handoff. Historical ADR names containing “publishing” in surviving cache-policy comments refer to provenance, not live database access.

## Security boundary decisions

Local RP session identifiers are never substituted for OP root identifiers. Local sessions authenticate with externally signed fixture JWTs through the real JWKS verifier. Governed mutations requiring unavailable Access authority stop before privileged mutation or audit intent. Defensive deny/epoch transitions retain their committed Governance event and explicitly report missing Access delivery; rollback must leave no local decision/event or cross-database audit artifact. Cross-database audit publication is scheduled after the owning transaction commits. No response claims revocation was delivered.

## Latest verification checkpoint

- Fresh isolated development `bin/rails db:prepare`: exit 0; 1,128 migrations per remaining 15 non-Queue stores, with Rails also preparing the isolated test configurations (2,256 migration completions total).
- Fresh isolated test `bin/rails db:prepare`: exit 0; 15 newly created `test_gov_removal_20261112_t3_*` databases and 1,128 completed migrations. The initial non-`test_` namespace was rejected by the unchanged safety guard, then corrected to the required namespace. No guard was disabled.
- Both commands used an explicitly inspected temporary database configuration loaded before Rails initialization. Queue has `database_tasks: false` only in that verification configuration. No existing development/test database or surviving repository schema dump was rebuilt.
- The first isolated build completed all migrations but exposed removed ExternalAuthentication/Sign-entry seed dependencies; their OP-only seed blocks were removed. Fresh builds then succeeded. Existing seed replay emits duplicate-constant warnings; the development bootstrap also reports missing FQDN feature registration. These warnings are retained as observed limits, not represented as a healthy application startup.
- Protected comparison after the builds: 1,694 frozen files unchanged; the executable shared seed file is the separately authorized cleanup recorded in `shared-seed-code-removal.json`.
- Current Preference/CSRF/owner-API/generic Turnstile batch: 70 tests, 651 assertions, zero failures/errors/skips. Real RP roles preserve authenticated preference writes and the two-passkey requirement; unsupported shared OP authority fails visibly. Anonymous Preference CSRF tests retain genuine 200/403 controls without unrelated RP credentials.
- Retained public API/policy/audit batch: 26 tests, 253 assertions, zero failures/errors/skips.
- Real PostgreSQL clock/serialization/reconciliation/concurrent-refusal batch: 12 tests, 78 assertions, zero failures/errors/skips.
- `bun run check` and final boot/eager-loading check passed at their latest checkpoint. Final whole-tree Ruby/ERB/security/test gates remain necessary after the last controller-test cleanup.

The temporary Turnstile replay refusal was an intermediate safety fix. A subsequent consumer audit found the ceremony API had no surviving callers; its OP-only API and tests were retired completely. Generic Turnstile verification and its 14 existing generic test cases remain. The observed fail-open reproduction is retained in temporary diagnostic logs; the final implementation does not preserve an unused ceremony stub.

The `.github` directory is still mounted `ro` (`findmnt` confirmation). The CI inventory patch remains unapplied for that concrete environment reason.

## Incomplete and out of scope

- `.github/workflows/ci.yml` remains mounted read-only. `git apply` failed with `Read-only file system`; the requested narrow database-list changes are preserved in `patches/remove-non-governance-workflow-databases.patch`. Environment-side repair was requested and approved, but a later retry still failed. No mount restriction was bypassed.
- Development/test `db:prepare`, final static guards, full Rails tests and final reference sweep remain pending.
- Production/shared databases were not modified or dropped.
- Existing ADRs/docs/checklists/diagrams are listed for the documentation owner, not rewritten.
- The requested rule name `genec` has no identifiable matching rule; no replacement policy was invented.
- No Red result is claimed for tests first executed after implementation or blocked before test execution.

## Documentation handoff inventory

Snapshot: 2026-11-12T14:07:02.622152+00:00. HEAD `43db4906742db2fb13b238c9ccde378e4e1583b4`; existing uncommitted changes affect this snapshot. Implementation and test reconciliation are still continuing.

These are actual reference hits for the documentation owner, not instructions to rewrite history. Existing ADRs/docs/checklists/diagrams remain unchanged. Historical reports preserve provenance.

Document scan: 3385 files; 684 contain references; 539 are historical paths. No unreadable document was encountered.

All 1694 frozen surviving schema/migration/document SHA-256 hashes match the original baseline. The authorized exclusive `db/migration_support/publishing_schema.rb` deletion is separate. The authorized executable `db/seeds.rb` cleanup is also separate: its SHA-256 is `8646d8db384551c9f8a8780730ae2c68e020e85df9c3dd0bf3dcacf9db677f07`, matching the cleanup receipt; no surviving migration/schema definition was edited.

### Runtime and intentional reference handoff

The broad Prism scan checked 488 deleted class/module definitions against 2816 surviving Ruby runtime files. Remaining runtime consumers: 0. The separate connection/removed-Model text scan covered 4802 non-document files outside tmp/vendor/generated runtime directories.

Intentional or separately owned references:

- `.github/workflows/ci.yml` retains retired database environment names because the workflow is mounted read-only. `patches/remove-non-governance-workflow-databases.patch` contains the corrective patch; it is not active configuration.
- Terraform Publishing object-storage declarations belong to the Press/infrastructure handoff: `terraform/environments/development/main.tf`, `terraform/environments/development/variables.tf`, `terraform/environments/development/outputs.tf`, `terraform/environments/staging-development/main.tf`, `terraform/environments/staging-development/variables.tf`, `terraform/environments/staging-development/outputs.tf`. No Terraform apply/destroy or bucket deletion was performed.
- `test/security/invariants/root_token_creation_invariant_test.rb`: retired class/table names are negative patterns prohibiting local authority token creation.
- `test/values/rp_cell_binding_test.rb`: retired connection names are rejected inputs.
- `database_consistency_2026_11_12_11_25_15.txt`: historical checker output, not runtime source. Historical document references below retain their provenance.

### Remaining test consumers at this snapshot

The following files still reference retired classes or connection metadata and require owner reconciliation. They are not counted as passing or automatically classified as harmless. String expressions can execute indirectly, and a static inventory can become vacuous after its only carriers are removed.

- `test/policies/operator_chronicle_policy_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/welcome_and_activity_seams_test.rb`: `OpOrgGrant`, `OperatorToken`.
- `test/controllers/base/step_up_intent_authority_test.rb`: `ClientStepUpCeremonyTransaction`.
- `test/controllers/base/settings_authority_slice_1g_test.rb`: `ClientToken`, `ClientTokenKind`, `ClientTokenStatus`.
- `test/controllers/base/app/welcomes_controller_test.rb`: `ClientToken`, `ClientTokenKind`.
- `test/controllers/base/app/full_access_gate_test.rb`: `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`.
- `test/controllers/base/app/rp_root_feature_refusal_test.rb`: `ClientAuthAdmissionBinding`, `IdentityPasskeyCeremonyCandidate`.
- `test/controllers/base/app/selector_controller_test.rb`: `ClientSignInFlow`, `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/app/dashboard_avatar_images_controller_test.rb`: `ClientToken`, `ClientTokenKind`.
- `test/controllers/base/app/roots_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/app/identity/withdrawals_controller_test.rb`: `ClientToken`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OpAppGrant`.
- `test/controllers/base/app/switchers_controller_test.rb`: `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/app/rp_selector_flow_test.rb`: `ClientToken`, `OpAppGrant`.
- `test/controllers/base/app/accounts_controller_test.rb`: `ClientOidcAuthorizationTransaction`, `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/app/preference/emails_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/app/organizations_controller_test.rb`: `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/app/verification/setups_controller_test.rb`: `ClientAuthAdmissionBinding`, `ClientStepUpCeremonyTransaction`, `ClientToken`, `ClientTokenKind`, `ClientTokenStatus`, `OpAppGrant`.
- `test/controllers/base/app/api/v0/avatar/dashboard_identities_controller_test.rb`: `ClientToken`, `OpAppGrant`.
- `test/controllers/base/app/api/v0/preferences/theme_controller_test.rb`: `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/app/organizations/memberships_controller_test.rb`: `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/app/billings_controller_test.rb`: `ClientToken`, `ClientTokenKind`, `OpAppGrant`.
- `test/controllers/base/org/accounts_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/org/staff_console_pages_test.rb`: `OpOrgGrant`, `OperatorToken`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/dashboard_avatar_images_controller_test.rb`: `OperatorToken`, `OperatorTokenKind`.
- `test/controllers/base/org/preference/emails_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb`: `OpOrgGrant`, `OperatorAuthAdmissionBinding`, `OperatorStepUpCeremonyTransaction`, `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/support/enforcement_approval_failures_test.rb`: `OpBaseOrgRecord`, `OpOrgGrant`, `OperatorDeviceSession`, `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/support/session_revocations_test.rb`: `ClientToken`, `ClientTokenKind`, `OpBaseOrgRecord`, `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/support/enforcement_cases_controller_test.rb`: `OpBaseOrgRecord`, `OpOrgGrant`, `OperatorDeviceSession`, `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/switcher_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/organizations/memberships_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/selector_controller_test.rb`: `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/lib/dpop_proof_verifier_test.rb`: `ClientDpopProofState`.
- `test/controllers/base/org/api/v0/avatar/dashboard_identities_controller_test.rb`: `OpOrgGrant`, `OperatorToken`, `OperatorTokenKind`.
- `test/controllers/base/org/api/v0/preferences/web_pushes_controller_test.rb`: `OperatorToken`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/api/v0/preferences/theme_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/org/api/v0/identity/owner_endpoints_test.rb`: `OpBaseOrgRecord`, `OpOrgGrant`, `OperatorToken`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/full_access_gate_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/iam/grants_controller_test.rb`: `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/iam/grant_pages_test.rb`: `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/iam/grant_submissions_test.rb`: `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/identity/removals_controller_test.rb`: `OpOrgGrant`, `OperatorStepUpCeremonyTransaction`, `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/org/identity/birthdates_controller_test.rb`: `OperatorToken`.
- `test/controllers/base/org/identity/rp_root_feature_refusal_test.rb`: `OperatorToken`.
- `test/controllers/base/org/organizations_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/org/roots_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/preference_authority_slice_1f_test.rb`: `ClientToken`, `ClientTokenKind`, `OpAppGrant`.
- `test/controllers/base/identity_read_only_pages_test.rb`: `ClientStepUpCeremonyTransaction`, `ClientToken`, `ClientTokenKind`, `ClientTokenStatus`, `OpAppGrant`, `OpOrgGrant`, `OperatorToken`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/base/public_controller_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/base/step_up_result_binding_negatives_test.rb`: `ClientToken`, `OperatorToken`.
- `test/controllers/base/identity_credential_management_test.rb`: `OpOrgGrant`, `OperatorToken`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/controllers/surface_sign_out_entry_and_birthdate_test.rb`: `OperatorToken`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/security/csrf_route_coverage_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/concerns/preference/base_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/concerns/authenticated_response_cache_policy_test.rb`: `ClientToken`, `ClientTokenKind`.
- `test/controllers/concerns/branch_coverage_batch9_sessions_and_zeros_test.rb`: `SecurityConsumedJti`.
- `test/controllers/concerns/authentication/token_service_test.rb`: `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/controllers/concerns/branch_coverage_batch2_test.rb`: `ClientToken`, `ClientTokenStatus`.
- `test/controllers/csp_violation_reports_controller_test.rb`: connection/string/metadata reference; inspect its executed contract.
- `test/controllers/tech/org/dashboards_controller_test.rb`: `OpOrgGrant`, `OperatorToken`.
- `test/integration/withdrawal_lifecycle_security_test.rb`: `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.
- `test/integration/tech_org_access_revocation_test.rb`: `OpOrgGrant`, `OperatorToken`.
- `test/integration/step_up_required_response_shape_test.rb`: `ClientToken`, `ClientTokenKind`, `ClientTokenStatus`, `OpAppGrant`, `OpOrgGrant`, `OperatorToken`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/tooling/database_migration_path_ownership_test.rb`: connection/string/metadata reference; inspect its executed contract.
- `test/values/rp_cell_binding_test.rb`: connection/string/metadata reference; inspect its executed contract.
- `test/concurrency/base_selector_single_write_http_test.rb`: `ClientDeviceSession`, `ClientOidcAuthorizationTransaction`, `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `OpAppGrant`, `OpAppGrantLogoutHint`, `OpOrgGrant`, `OpOrgGrantLogoutHint`, `OperatorDeviceSession`, `OperatorOidcAuthorizationTransaction`, `OperatorToken`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`.
- `test/concurrency/step_up_email_lock_order_test.rb`: `ClientStepUpCeremonyTransaction`, `ClientStepUpSession`, `ClientToken`, `OpBaseAppRecord`.
- `test/concurrency/org_iam_capability_revocation_race_test.rb`: `OpOrgGrant`, `OperatorDeviceSession`, `OperatorToken`.
- `test/concurrency/org_iam_target_eligibility_race_test.rb`: `OpOrgGrant`, `OperatorDeviceSession`, `OperatorToken`.
- `test/concurrency/base_step_up_admission_reference_race_test.rb`: `ClientStepUpCeremonyTransaction`, `ClientStepUpSession`, `ClientToken`, `OpBaseAppRecord`, `OpBaseOrgRecord`, `OperatorStepUpCeremonyTransaction`, `OperatorStepUpSession`, `OperatorToken`.
- `test/concurrency/org_iam_principal_commit_race_test.rb`: `OpBaseOrgRecord`, `OpOrgAuthorityStop`, `OpOrgAuthorityStopEpochCutoff`, `OpOrgAuthorityStopGrantTarget`, `OpOrgAuthorityStopParticipant`, `OpOrgAuthorityStopRootTarget`, `OpOrgGrant`, `OperatorDeviceSession`, `OperatorToken`.
- `test/security/invariants/lifecycle_direct_state_write_invariant_test.rb`: connection/string/metadata reference; inspect its executed contract.
- `test/security/invariants/root_token_creation_invariant_test.rb`: connection/string/metadata reference; inspect its executed contract.
- `test/security/invariants/authorization_failure_audit_invariant_test.rb`: `OperatorToken`, `OperatorTokenKind`.
- `test/security/invariants/refresh_token_reuse_invariant_test.rb`: `ClientToken`, `ClientTokenBindingMethod`, `ClientTokenDbscStatus`, `ClientTokenKind`, `ClientTokenStatus`, `ClientVerification`, `OperatorTokenBindingMethod`, `OperatorTokenDbscStatus`, `OperatorTokenKind`, `OperatorTokenStatus`, `OperatorVerification`.

### Documentation paths requiring lifecycle-aware owner review

#### adr

- `adr/README.md`
- `adr/api-collection-contract.md`
- `adr/api-error-format-problem-details.md`
- `adr/audit-findings-2026-03-30.md`
- `adr/authentication-assurance-level-boundaries.md`
- `adr/base-auth-ceremony-and-seven-rp-boundary.md`
- `adr/cosmos-base-surface-decomposition.md`
- `adr/cosmos-common-database-connections.md`
- `adr/cosmos-sphere-surfaces-and-rp-independence.md`
- `adr/database-consistency-repair-plan.md`
- `adr/database-names-without-region.md`
- `adr/database-trigger-usage-boundary.md`
- `adr/device-session-dbsc-device-id-boundary.md`
- `adr/email-otp-race-condition-fixes.md`
- `adr/emergency-secret-credential-commit-acknowledgement.md`
- `adr/fakecloud-podman-staging-environment.md`
- `adr/global-and-publishing-default-no-store-policy.md`
- `adr/global-regional-database-ownership.md`
- `adr/identity-db-scope-reduction-and-solid-setup.md`
- `adr/jump-directed-rails-handoff-contract.md`
- `adr/logout-primitive-and-composition.md`
- `adr/news-is-timeline.md`
- `adr/op-auth-rp-authentication-responsibility-separation.md`
- `adr/org-entra-single-tenant-credential-configuration.md`
- `adr/owner-api-openapi-description-deferred.md`
- `adr/publish-repository-importmap-boundary.md`
- `adr/publishing-db-content-authority.md`
- `adr/publishing-persistence-polymorphism-prohibition.md`
- `adr/publishing-taxonomy-architecture.md`
- `adr/publishing-twelve-family-encrypted-persistence.md`
- `adr/read-only-content-surfaces-in-rails.md`
- `adr/regional-docs-news-content-model.md`
- `adr/regional-help-surface-direction.md`
- `adr/retainable-concern-and-retention-purge.md`
- `adr/root-login-establishment-boundary.md`
- `adr/runtime-secret-isolation-deferred.md`
- `adr/security-audit-findings-2026-06-13.md`
- `adr/session-token-hardening-baseline.md`
- `adr/sign-up-cycle-cancellation-retention.md`
- `adr/sign-up-flow-admission-binding-and-cardinality.md`
- `adr/social-login-cooldown-and-one-shot-completion.md`
- `adr/solid-cache-removal-and-valkey-cache-separation.md`
- `adr/staging-aurora-postgresql-topology.md`
- `adr/step-up-authentication-redesign.md`
- `adr/surface-database-connection-naming.md`
- `adr/tech-and-palm-browser-rp-participation.md`

#### checklist

- `docs/checklists/avatar-ownership.md`
- `docs/checklists/contact-identifiers.md`
- `docs/checklists/identifier-contracts.md`

#### document

- `.agents/harnesses/rules/generic/routing.mdc`
- `.agents/harnesses/rules/project/session-issuance.mdc`
- `.agents/harnesses/rules/project/value-object-boundaries.mdc`
- `docs/architecture/avatar-authority-contract-proposal.md`
- `docs/architecture/database-authority-placement.md`
- `docs/architecture/database-boundaries.md`
- `docs/architecture/dds.md`
- `docs/architecture/dpop.md`
- `docs/architecture/hld.md`
- `docs/architecture/op-rp-ownership-manifest.md`
- `docs/architecture/persona-organization-authority.md`
- `docs/architecture/preference.md`
- `docs/architecture/principal-zenith-membership-organization-placement.md`
- `docs/architecture/publishing-persistence.md`
- `docs/architecture/sns-subject-resource-grill.md`
- `docs/backlog/2026-10-22-invitation-email-abuse-policy.md`
- `docs/backlog/2026-10-22-pre-stop-jwt-accepted-after-operator-restore.md`
- `docs/backlog/2026-11-10-core-security-review-followups.md`
- `docs/guides/test-profiling.md`
- `docs/operations/aws-production-service-inventory.md`
- `docs/operations/db-workflow.md`
- `docs/operations/local-aws-fakecloud.md`
- `docs/operations/solid-queue-runtime.md`
- `docs/reference/api-design-standards.md`
- `docs/reference/forbidden-rails-methods.md`
- `docs/reference/identifier-conventions.md`
- `docs/security/app-secret.md`
- `docs/security/authentication-capacity-admission.md`
- `docs/security/identifier-encryption-inventory.md`
- `docs/security/org-emergency-access.md`
- `docs/security/session-limit.md`
- `docs/security/step-up-operation-inventory.md`

#### evidence

- `evidence/2026-09-03-cms-architecture-remediation-phase-1.md`
- `evidence/2026-09-03-publishing-entries-public-id-contract.md`
- `evidence/2026-09-03-publishing-media-usage-split.md`
- `evidence/2026-09-03-publishing-phase-1b-finalization.md`
- `evidence/2026-09-03-publishing-phase-cde.md`
- `evidence/2026-09-04-dependency-audit-and-coverage.md`
- `evidence/2026-09-04-neon-production-schema-imaging.md`
- `evidence/2026-09-04-publishing-management-ui.md`
- `evidence/2026-09-04-publishing-twelve-family-encryption.md`
- `evidence/2026-09-05-merge-origin-feature-verification.md`
- `evidence/2026-09-05-merge-package-update-and-review.md`
- `evidence/2026-09-05-solid-cache-valkey-migration.md`
- `evidence/2026-09-06-publishing-cms-lifecycle.md`
- `evidence/2026-09-06-shrine-fakecloud-attachments.md`
- `evidence/2026-09-07-rails-test-and-comment-audit.md`
- `evidence/2026-09-08-development-database-rebuild.md`
- `evidence/2026-09-08-global-regional-database-ownership-decision.md`
- `evidence/2026-09-08-global-regional-database-split-assessment.md`
- `evidence/2026-09-08-inertia-vite-production-assets.md`
- `evidence/2026-09-08-podman-compose-devcontainer-coexistence.md`
- `evidence/2026-09-10-publishing-pagy-offset-pagination.md`
- `evidence/2026-09-11-rfc9068-access-token-profile-hardening.md`
- `evidence/2026-09-12-edit-publishing-management-surface.md`
- `evidence/2026-09-13-auth-boundary-consolidation.md`
- `evidence/2026-09-14-fakecloud-s3-runtime-verification.md`
- `evidence/2026-09-17-auth-body-limit-blockers.md`
- `evidence/2026-09-17-oidc-connection-revocation.md`
- `evidence/2026-09-17-oidc-revocation-scope.md`
- `evidence/2026-09-17-rp-revoke-lock-order.md`
- `evidence/2026-09-17-rp-session-lock-order.md`
- `evidence/2026-09-17-rp-session-realm-hardening.md`
- `evidence/2026-09-17-signup-guardrail.md`
- `evidence/2026-09-18-rp-session-issuance-boundary.md`
- `evidence/2026-09-18-rp-session-logout-state-lock.md`
- `evidence/2026-09-18-rp-session-refresh-lock-order.md`
- `evidence/2026-09-20-otp-session-binding-V1W2.md`
- `evidence/2026-09-20-phase-08-totp-lifecycle-T8R4.md`
- `evidence/2026-09-20-phase-09-safe-db-slices-R6T7.md`
- `evidence/2026-09-20-step-up-atomic-consumption-H6J7.md`
- `evidence/2026-09-21-auth-base-root-session-regression-Y3Z4.md`
- `evidence/2026-09-21-auth-ceremony-database-clock-W3X4.md`
- `evidence/2026-09-21-database-clock-state-transitions-H8J9.md`
- `evidence/2026-09-21-devcontainer-test-env-K3N8.md`
- `evidence/2026-09-21-email-enqueue-audit-C8D9.md`
- `evidence/2026-09-21-email-enqueue-failure-audit-L1M2.md`
- `evidence/2026-09-21-oidc-connection-database-clock-Y4Z5.md`
- `evidence/2026-09-21-oidc-session-limit-and-retention-validation-N7P8.md`
- `evidence/2026-09-21-oidc-transaction-database-clock-T1U2.md`
- `evidence/2026-09-21-phase-09-reconstruction-X4Y5.md`
- `evidence/2026-09-21-phase-18-email-audit-and-gates-D0E1.md`
- `evidence/2026-09-21-retention-acceptance-rebaseline-R4S5.md`
- `evidence/2026-09-21-retention-plan-reaudit-T6U7.md`
- `evidence/2026-09-21-retention-time-consistency-U1V2.md`
- `evidence/2026-09-22-auth-base-cross-store-handoff-blocker-V4W5.md`
- `evidence/2026-09-22-auth-ceremony-atomic-rotation-C6D7.md`
- `evidence/2026-09-22-auth-cross-store-shape-review-P8Q9.md`
- `evidence/2026-09-22-edit-publishing-route-revalidation-C3D4.md`
- `evidence/2026-09-22-oidc-revoke-connection-revalidation-V2W3.md`
- `evidence/2026-09-22-retention-acceptance-revalidation-W4X5.md`
- `evidence/2026-09-22-retention-frozen-plan-rereview-R9S0.md`
- `evidence/2026-09-22-retention-notification-route-revalidation-N6P7.md`
- `evidence/2026-09-22-rp-session-revocation-revalidation-D5E6.md`
- `evidence/2026-09-23-cf005-queue-runtime-P6Q7.md`
- `evidence/2026-09-23-current-quality-gates-N9P0.md`
- `evidence/2026-09-23-retired-rp-reference-cleanup-E5F6.md`
- `evidence/2026-09-24-device-session-token-integrity-A7KQ.md`
- `evidence/2026-09-24-global-postgresql-audit-final-E6N2.md`
- `evidence/2026-09-24-postgresql-integrity-followup-B9Q2.md`
- `evidence/2026-09-24-token-actor-integrity-C5R8.md`
- `evidence/2026-09-25-integrated-auth-avatar-warp-H7J4.md`
- `evidence/2026-09-25-postgresql-test-host-recovery-P3K9.md`
- `evidence/2026-09-26-integrated-auth-remaining-pass-Q4T8.md`
- `evidence/2026-09-26-minitest-coverage-increase-K7Q2.md`
- `evidence/2026-09-30-edit-org-landing-M8Q2.md`
- `evidence/2026-10-01-default-no-store-policy-migration-K7Q2.md`
- `evidence/2026-10-02-sign-p0-baseline-d1-T5N3.md`
- `evidence/2026-10-03-app-secret-count-foundation-6S2V.md`
- `evidence/2026-10-03-app-secret-name-commit-6V2N.md`
- `evidence/2026-10-03-app-secret-success-receipt-5M8R.md`
- `evidence/2026-10-03-auth-boundary-foundation-7P4K.md`
- `evidence/2026-10-03-base-app-get-navigation-8N4Q.md`
- `evidence/2026-10-03-bootstrap-totp-base-finalization-9C5B.md`
- `evidence/2026-10-03-registration-evidence-isolated-4R8C.md`
- `evidence/2026-10-03-rubocop-offense-cleanup-L4N8.md`
- `evidence/2026-10-03-step-up-totp-delivery-revocation-6F2A.md`
- `evidence/2026-10-03-test-quality-dead-code-doc-sync-T7Q4.md`
- `evidence/2026-10-04-app-com-legacy-verification-surface-retirement-8B6Q.md`
- `evidence/2026-10-04-app-secret-encoding-refusal-2K7M.md`
- `evidence/2026-10-04-app-secret-manual-reservation-8J2S.md`
- `evidence/2026-10-04-app-secret-revocation-inventory-7B3M.md`
- `evidence/2026-10-04-app-secret-validated-retirement-4K8P.md`
- `evidence/2026-10-04-auth-continuity-revocation-races-2N7C.md`
- `evidence/2026-10-04-base-finalization-logout-cancellation-4L7R.md`
- `evidence/2026-10-04-base-step-up-finalization-write-faults-8W3N.md`
- `evidence/2026-10-04-credential-inventory-expiry-7V3A.md`
- `evidence/2026-10-04-credential-removal-serialization-9R2M.md`
- `evidence/2026-10-04-credential-revocation-finalization-race-6R8W.md`
- `evidence/2026-10-04-credential-transition-revocation-flags-7V2D.md`
- `evidence/2026-10-04-credential-transition-session-binding-2A6F.md`
- `evidence/2026-10-04-credential-transition-writer-enumeration-9S4K.md`
- `evidence/2026-10-04-expired-continuity-revocation-retention-6F9A.md`
- `evidence/2026-10-04-latest-pending-step-up-fallback-retirement-7N4D.md`
- `evidence/2026-10-04-legacy-cancellation-audit-retirement-9D3J.md`
- `evidence/2026-10-04-legacy-step-up-lifecycle-retirement-1R7C.md`
- `evidence/2026-10-04-legacy-step-up-timing-retirement-4H8P.md`
- `evidence/2026-10-04-local-login-credential-revocation-4C8R.md`
- `evidence/2026-10-04-local-login-revocation-races-7Q2B.md`
- `evidence/2026-10-04-oidc-credential-revocation-5K9D.md`
- `evidence/2026-10-04-oidc-expiry-precision-9H4M.md`
- `evidence/2026-10-04-oidc-result-effective-deadline-2D8N.md`
- `evidence/2026-10-04-org-dashboard-login-return-6R8N.md`
- `evidence/2026-10-04-org-normal-root-and-step-up-5W8N.md`
- `evidence/2026-10-04-org-passkey-emergency-boundary-8J5R.md`
- `evidence/2026-10-04-passkey-slot-serialization-4S7K.md`
- `evidence/2026-10-04-registration-admission-authority-6A4P.md`
- `evidence/2026-10-04-registration-fresh-schema-5J8C.md`
- `evidence/2026-10-04-secret-discard-irreversibility-2F9C.md`
- `evidence/2026-10-04-secret-issuance-fact-immutability-4J6P.md`
- `evidence/2026-10-04-selected-context-step-up-invalidation-7M2D.md`
- `evidence/2026-10-04-step-up-assurance-floor-refusal-5P8A.md`
- `evidence/2026-10-04-step-up-cancellation-race-clock-9M4B.md`
- `evidence/2026-10-04-step-up-decision-clock-6T2M.md`
- `evidence/2026-10-04-step-up-purge-reference-failure-4Q6R.md`
- `evidence/2026-10-04-step-up-scope-path-boundaries-3H7N.md`
- `evidence/2026-10-05-app-secret-absent-owner-barrier-3F7K.md`
- `evidence/2026-10-05-app-secret-current-regressions-4R8J.md`
- `evidence/2026-10-05-app-secret-durable-audit-matching-4H9S.md`
- `evidence/2026-10-05-app-secret-http-continuation-6M8Q.md`
- `evidence/2026-10-05-app-secret-issuance-queue-continuation-5N7C.md`
- `evidence/2026-10-05-app-secret-mixed-reservation-concurrency-7M2V.md`
- `evidence/2026-10-05-app-secret-omission-collection-7P4K.md`
- `evidence/2026-10-05-app-secret-outbox-only-recovery-2K9W.md`
- `evidence/2026-10-05-app-secret-payload-failure-boundaries-6K3P.md`
- `evidence/2026-10-05-app-secret-signup-payload-collection-5T8N.md`
- `evidence/2026-10-05-app-secret-terminal-signup-collection-6J8R.md`
- `evidence/2026-10-05-step-up-observability-and-transition-consolidation-7H3K.md`
- `evidence/2026-10-05-ui-components-T8D2.md`
- `evidence/2026-10-06-admission-takeover-3K8Q.md`
- `evidence/2026-10-06-concern-included-hook-audit-K7C3.md`
- `evidence/2026-10-06-final-verification-partial-8R2M.md`
- `evidence/2026-10-06-phase-00-baseline-A1B2.md`
- `evidence/2026-10-06-phase-15-step-up-Q4R6.md`
- `evidence/2026-10-07-admission-issuer-model-matrix-K6B9.md`
- `evidence/2026-10-07-auth-email-delivery-binding-R7K2.md`
- `evidence/2026-10-07-ceremony-otp-primitives-2B6V.md`
- `evidence/2026-10-07-com-email-restart-locator-H4L8.md`
- `evidence/2026-10-07-contact-source-audit-R4C9.md`
- `evidence/2026-10-07-settings-contact-otp-foundation-Q8M4.md`
- `evidence/2026-10-07-signup-state-inventory-G2D8.md`
- `evidence/2026-10-07-step-up-conflict-intent-C8R2.md`
- `evidence/2026-10-07-step-up-conflict-intent-I9C3.md`
- `evidence/2026-10-07-step-up-fixture-cookie-id-isolation-J3R8.md`
- `evidence/2026-10-08-architecture-visibility-ratchet-7C3V.md`
- `evidence/2026-10-08-ceremony-finite-deadlines-3D7P.md`
- `evidence/2026-10-08-ceremony-keyed-receipts-8Q2R.md`
- `evidence/2026-10-08-ceremony-terminal-sql-protection-gap-7C2D.md`
- `evidence/2026-10-08-otp-legacy-and-notifier-retirement-4N8D.md`
- `evidence/2026-10-09-auth-acceptance-repair-H9K4.md`
- `evidence/2026-10-09-model-class-structure-reorder-K3RW.md`
- `evidence/2026-10-10-avatar-period-exclusion-G6Q2.md`
- `evidence/2026-10-10-avatar-provisioning-concrete-period-S4H8.md`
- `evidence/2026-10-10-full-gate-group-R4S7.md`
- `evidence/2026-10-10-full-gate-p10a-Q8R3.md`
- `evidence/2026-10-10-p9-five-day-gate-X5D2.md`
- `evidence/2026-10-10-p9-four-direction-full-gate-V8Q2.md`
- `evidence/2026-10-10-p9-lifecycle-gate-P9L4.md`
- `evidence/2026-10-10-p9-registry-accept-gate-J4N8.md`
- `evidence/2026-10-10-p9-registry-accept-history-gate-Y2H4.md`
- `evidence/2026-10-10-p9-registry-accept-instant-gate-W6K3.md`
- `evidence/2026-10-10-p9-registry-accept-replay-gate-N4J6.md`
- `evidence/2026-10-10-p9-registry-request-gate-R8M2.md`
- `evidence/2026-10-10-p9-source-generation-gate-H6P2.md`
- `evidence/2026-10-11-avatar-committed-writer-preparation-M7R5.md`
- `evidence/2026-10-11-avatar-registry-directions-8F3K.md`
- `evidence/2026-10-11-local-migrate-and-test-run-repair-K4T7.md`
- `evidence/2026-10-11-org-telephone-identity-backfill-K6V2.md`
- `evidence/2026-10-11-org-telephone-legacy-proof-inventory-D7K3.md`
- `evidence/2026-10-11-preference-architecture-history-and-drift.md`
- `evidence/2026-10-12-avatar-concurrency-current-Q2F6.md`
- `evidence/2026-10-12-avatar-p10a-generation-reuse-G5N2.md`
- `evidence/2026-10-12-avatar-p10a-grant-recheck-R3V7.md`
- `evidence/2026-10-12-avatar-p10a-transfer-grant-matrix-Z4M6.md`
- `evidence/2026-10-12-avatar-p7-concurrency-7K4M.md`
- `evidence/2026-10-12-cross-db-purge-failure-retry-P5H7.md`
- `evidence/2026-10-12-email-reentry-references-Q4M8.md`
- `evidence/2026-10-12-identity-candidate-ref-issuer-T5Q8.md`
- `evidence/2026-10-12-oidc-authorization-transaction-references-K2R4.md`
- `evidence/2026-10-12-org-telephone-not-null-cutover-N8Q4.md`
- `evidence/2026-10-12-otp-email-noticed-final-Z4N7.md`
- `evidence/2026-10-12-otp-identifier-history-focused-7NQ4.md`
- `evidence/2026-10-12-p11b-retention-deferral-R8L2.md`
- `evidence/2026-10-12-p3b-purpose-operation-binding-Q7R1.md`
- `evidence/2026-10-12-p3d-adapter-retirement-gate-J8R4.md`
- `evidence/2026-10-12-p3d-ceremony-matrix-B7Q5.md`
- `evidence/2026-10-12-p3d-otp-concurrency-matrix-P6R2.md`
- `evidence/2026-10-12-p3d-route-inventory-K4L8.md`
- `evidence/2026-10-12-public-id-capacity-extension-V2J6.md`
- `evidence/2026-10-12-public-id-issuers-H4J2.md`
- `evidence/2026-10-12-resume-gate-H8K4.md`
- `evidence/2026-10-12-resume-minitest-sample-P7L4.md`
- `evidence/2026-10-12-secret-credential-references-S7L2.md`
- `evidence/2026-10-12-social-ceremony-references-H5N6.md`
- `evidence/2026-10-12-step-up-ceremony-references-J7P3.md`
- `evidence/2026-10-12-totp-ceremony-references-R2T6.md`
- `evidence/2026-10-13-avatar-standard-test-boundaries-S4N8.md`
- `evidence/2026-10-13-avatar-step17-partial-J7Q4.md`
- `evidence/2026-10-13-bcl-removal-preflight-BCL3.md`
- `evidence/2026-10-13-csrf-strict-loading-revalidation-P5Q8.md`
- `evidence/2026-10-13-first-party-rp-completion-uri-matrix-P7V4.md`
- `evidence/2026-10-13-nine-independent-acceptance-N6A2.md`
- `evidence/2026-10-13-step-up-challenge-reference-P7N4.md`
- `evidence/2026-10-14-avatar-ownership-consumer-ledger-A7Q4.md`
- `evidence/2026-10-14-browser-rp-writer-resource-N6H2.md`
- `evidence/2026-10-14-signout-parent-child-repair-M6R2.md`
- `evidence/2026-10-14-signout-refresh-deadlock-fix-R7P4.md`
- `evidence/2026-10-14-tdd-signout-fail-fast-T5D2.md`
- `evidence/2026-10-15-acceptance-follow-up-implementation-K7M3.md`
- `evidence/2026-10-16-r2-wu01-7KQ2.md`
- `evidence/2026-10-16-r2-wu02-3D7M.md`
- `evidence/2026-10-16-r2-wu03-7P4M.md`
- `evidence/2026-10-16-r2-wu05-4J7N.md`
- `evidence/2026-10-17-r4-target-client-ids-R4T1.md`
- `evidence/2026-10-17-r5-wu13-publishing-authority-P13A.md`
- `evidence/2026-10-17-r5-wu18-standby-terminology-and-legacy-gaps-S18T.md`
- `evidence/2026-10-17-r5-wu18a-isolated-rehearsal-aggregate-A18R.md`
- `evidence/2026-10-17-r5-wu19-wu20-source-and-status-W19S.md`
- `evidence/2026-10-17-runtime-role-provisioning-R3P7.md`
- `evidence/2026-10-18-r5-protocol-continuation-R5C8.md`
- `evidence/2026-10-19-consistency-constraint-review-J8Q2.md`
- `evidence/2026-10-19-database-consistency-baseline-M8K2.md`
- `evidence/2026-10-19-database-consistency-fk-index-K4Q7.md`
- `evidence/2026-10-19-database-consistency-inverse-keys-R6J3.md`
- `evidence/2026-10-19-database-consistency-publishing-review-K3V9.md`
- `evidence/2026-10-19-projected-and-nullable-contracts-G2S7.md`
- `evidence/2026-10-19-publishing-ordered-positions-P6T4.md`
- `evidence/2026-10-19-publishing-revision-sequence-S4N2.md`
- `evidence/2026-10-19-publishing-version-sequence-V5P8.md`
- `evidence/2026-10-19-three-retained-scope-R8M2.md`
- `evidence/2026-10-20-brakeman-remediation-B6K2.md`
- `evidence/2026-10-20-database-consistency-resumption-D8K4.md`
- `evidence/2026-10-20-isolated-test-fleet-retirement-Q8P4.md`
- `evidence/2026-10-20-model-validation-and-check-constraints-V5T3.md`
- `evidence/2026-10-20-org-organization-consolidation-Q7M2.md`
- `evidence/2026-10-20-publishing-redundant-locale-unique-indexes-R7M2.md`
- `evidence/2026-10-20-required-creation-fields-N7B2.md`
- `evidence/2026-10-20-session-fixation-result-retry-S7F3.md`
- `evidence/2026-10-20-unique-vocabulary-keys-U4K8.md`
- `evidence/2026-10-20-validation-and-constraint-alignment-T6W3.md`
- `evidence/2026-10-23-wu01-local-sign-in-flow-removal-L0R1.md`
- `evidence/2026-10-23-wu24cd-binding-storage-C7D4.md`
- `evidence/2026-10-23-wu44-root-issuance-epoch-E4R4.md`
- `evidence/2026-10-24-brakeman-signup-principal-B4S1.md`
- `evidence/2026-10-24-wu24h-binding-ownership-H8P2.md`
- `evidence/2026-10-25-global-region-canonicalization-R1G8.md`
- `evidence/2026-10-25-schema-drift-hmac-role-H7Q3.md`
- `evidence/2026-10-25-schema-dump-verification-R4V8.md`
- `evidence/2026-10-25-search-storage-first-migration-S3M1.md`
- `evidence/2026-10-25-visa-controller-boundaries-V8C2.md`
- `evidence/2026-10-25-wu10-standard-refresh-R7K2.md`
- `evidence/2026-10-25-wu15-16-22-op-authority-stop-6B3Q.md`
- `evidence/2026-10-25-wu15-16-22-suite-check-C7M4.md`
- `evidence/2026-10-25-wu24h-dead-social-readers-D24S.md`
- `evidence/2026-10-25-wu30-one-time-step-up-K7Q2.md`
- `evidence/2026-10-26-acceptance-gap-tests-9Q2F.md`
- `evidence/2026-10-26-cycle-stage3-execution-V4F2.md`
- `evidence/2026-10-26-database-consistency-cycle-findings-X7P4.md`
- `evidence/2026-10-26-rubocop-autocorrect-review-H7Q2.md`
- `evidence/2026-10-26-sign-out-so1-legacy-removal-A4C2.md`
- `evidence/2026-10-26-wu30-step-up-consumption-M3A7.md`
- `evidence/2026-10-26-wu38-stuck-registration-report-S8J4.md`
- `evidence/2026-10-26-wu44-remaining-acceptance-X9R2.md`
- `evidence/2026-10-27-a7-secret-claim-unfinished-registration-T5W8.md`
- `evidence/2026-10-27-acceptance-partials-V8M2.md`
- `evidence/2026-10-27-full-suite-repair-plan-a-M2V9.md`
- `evidence/2026-10-27-org-realm-length-partial-P3R8.md`
- `evidence/2026-10-27-social-crossing-wedge-tests-X7K2.md`
- `evidence/2026-10-28-signup-social-restart-refused-S7G4.md`
- `evidence/2026-10-29-wu4-otp-tests-G6P2.md`
- `evidence/2026-10-29-wu4-passkey-suite-progress-W4H2.md`
- `evidence/2026-10-29-wu4-rp-contract-tests-C4R9.md`
- `evidence/2026-10-29-wu4-secret-and-owner-D8K2.md`
- `evidence/2026-10-29-wu4-session-contract-tests-L2H5.md`
- `evidence/2026-10-29-wu4-shared-contract-tests-P8N4.md`
- `evidence/2026-10-29-wu4-test-loading-T9Q2.md`
- `evidence/2026-10-29-wu4-withdrawal-notifier-S7M3.md`
- `evidence/2026-10-29-wu5-test-db-rebuild-Q4X8.md`
- `evidence/2026-10-30-auth-email-otp-cooldown-order-6T3G.md`
- `evidence/2026-10-30-wu-a14-rau46-cleanup-status-translation-N8C5.md`
- `evidence/2026-10-31-org-secret-active-owner-Q7V4.md`
- `evidence/2026-10-31-org-secret-bootstrap-device-G8P2.md`
- `evidence/2026-10-31-org-secret-update-owner-N3K8.md`
- `evidence/2026-10-31-passkey-deadline-clock-stub-P9S4.md`
- `evidence/2026-10-31-wu4-session-docs-current-D7Q3.md`
- `evidence/2026-10-31-wu7-structure-dump-recovery-R7Q2.md`
- `evidence/2026-10-31-wu9-app-org-supplemental-state-W9P4.md`
- `evidence/2026-10-31-wua14-cleanup-reference-V3K7.md`
- `evidence/2026-10-31-wua14-redirect-tests-J3F5.md`
- `evidence/2026-10-31-wua4-admission-parent-lock-B7M4.md`
- `evidence/2026-10-31-wua4-admission-reference-race-T9K6.md`
- `evidence/2026-10-31-wua4-auth-email-lint-B4W6.md`
- `evidence/2026-10-31-wua4-cancellation-device-T2H6.md`
- `evidence/2026-10-31-wua4-email-owner-Q3K8.md`
- `evidence/2026-10-31-wua4-identity-stop-atomic-epoch-G5N8.md`
- `evidence/2026-10-31-wua4-identity-stop-enqueue-refusal-N4C9.md`
- `evidence/2026-10-31-wua4-identity-stop-reason-Q4T7.md`
- `evidence/2026-10-31-wua4-identity-stop-scope-V6Q2.md`
- `evidence/2026-10-31-wua4-local-signup-binding-inventory-D6N9.md`
- `evidence/2026-10-31-wua4-org-lifecycle-after-commit-V8R5.md`
- `evidence/2026-10-31-wua4-org-stepup-reference-race-Q7V3.md`
- `evidence/2026-10-31-wua4-org-stop-duplicate-race-B9W2.md`
- `evidence/2026-10-31-wua4-passkey-name-commit-boundary-J5V7.md`
- `evidence/2026-10-31-wua4-passkey-name-outer-transaction-H2V9.md`
- `evidence/2026-10-31-wua4-passkey-reservation-device-V9C2.md`
- `evidence/2026-10-31-wua4-presentation-device-L8R2.md`
- `evidence/2026-10-31-wua4-reattempt-actor-E2L5.md`
- `evidence/2026-10-31-wua4-reattempt-device-B5J9.md`
- `evidence/2026-10-31-wua4-reauth-parent-lock-V6M2.md`
- `evidence/2026-10-31-wua4-reservation-device-F7P4.md`
- `evidence/2026-10-31-wua4-risk-stop-after-commit-R8D3.md`
- `evidence/2026-10-31-wua4-secret-confirm-P4J6.md`
- `evidence/2026-10-31-wua4-secret-device-A2R9.md`
- `evidence/2026-10-31-wua4-secret-order-F8N2.md`
- `evidence/2026-10-31-wua4-secret-revoke-R7D3.md`
- `evidence/2026-10-31-wua4-signin-resend-test-transactions-Q8N4.md`
- `evidence/2026-10-31-wua4-stepup-delivery-receipt-conflict-Q2X5.md`
- `evidence/2026-10-31-wua4-stepup-lock-race-N4X8.md`
- `evidence/2026-10-31-wua4-stepup-receipt-preflight-J9T4.md`
- `evidence/2026-10-31-wua4-stop-callback-boundaries-L3J8.md`
- `evidence/2026-10-31-wua4-stop-delivery-retry-F6K2.md`
- `evidence/2026-10-31-wua4-stop-duplicate-race-P6T4.md`
- `evidence/2026-10-31-wua4-stop-duplicate-rollback-H5P8.md`
- `evidence/2026-10-31-wua4-stop-receipt-facts-N7P3.md`
- `evidence/2026-10-31-wua4-stop-receipt-sender-G6K4.md`
- `evidence/2026-10-31-wua4-stop-sweep-poison-H8M3.md`
- `evidence/2026-10-31-wua4-stop-sweep-realm-isolation-W5D8.md`
- `evidence/2026-10-31-wua4-stop-test-counts-V5R3.md`
- `evidence/2026-10-31-wua4-telephone-owner-Z2G5.md`
- `evidence/2026-10-31-wua4-token-device-owner-M3P6.md`
- `evidence/2026-10-31-wua4-totp-name-outer-transaction-C3M8.md`
- `evidence/2026-10-31-wua4-withdrawal-suspend-after-commit-M6R9.md`
- `evidence/2026-10-31-wua4-withdrawal-termination-after-commit-K3V7.md`
- `evidence/2026-10-31-wua5-passkey-audit-required-P7J4.md`
- `evidence/2026-10-31-wua5-passkey-owner-binding-C8F4.md`
- `evidence/2026-10-31-wua8-cell-logout-hint-R5P8.md`
- `evidence/2026-10-31-wux-structure-dumps-R7T3.md`
- `evidence/2026-10-31-wux1-org-settings-and-scope-K9J4.md`
- `evidence/2026-10-31-wux2-case-ledger-N6Q4.md`
- `evidence/2026-11-01-wu9-org-status-fk-validation-J4K6.md`
- `evidence/2026-11-01-wu9-visa-post-continuation-Q7M2.md`
- `evidence/2026-11-01-wua2-email-secret-back-refusal-K7N3.md`
- `evidence/2026-11-01-wua2-parent-cancel-atomic-J4V8.md`
- `evidence/2026-11-01-wua2-registration-completion-shape-inventory-Q4J8.md`
- `evidence/2026-11-01-wua2-social-refusal-matrix-contract-A6V9.md`
- `evidence/2026-11-01-wua2-social-signup-back-restart-R7M4.md`
- `evidence/2026-11-01-wua3-ac53-and-state-observation-J8R3.md`
- `evidence/2026-11-01-wua3-admission-continuity-purge-R8L3.md`
- `evidence/2026-11-01-wua3-binding-fk-normalization-D5K8.md`
- `evidence/2026-11-01-wua3-coupled-migration-status-current-Y3P8.md`
- `evidence/2026-11-01-wua3-coupled-status-local-cutover-C7N5.md`
- `evidence/2026-11-01-wua3-migration-status-refresh-F4T2.md`
- `evidence/2026-11-01-wua3-visa-writer-read-boundary-H5S2.md`
- `evidence/2026-11-01-wua4-passkey-registration-savepoint-Q4W8.md`
- `evidence/2026-11-01-wua4-secret-confirm-lost-commit-ack-R7M2.md`
- `evidence/2026-11-01-wua4-secret-confirm-savepoint-commit-Z3Q7.md`
- `evidence/2026-11-01-wua4-secret-name-final-commit-B6C4.md`
- `evidence/2026-11-01-wua4-secret-name-lost-commit-ack-P4D8.md`
- `evidence/2026-11-01-wua4-secret-name-proof-race-F5K9.md`
- `evidence/2026-11-01-wua4-secret-name-savepoint-commit-X5D9.md`
- `evidence/2026-11-01-wua4-telephone-finalizer-source-commit-D9H5.md`
- `evidence/2026-11-01-wua4-xdb03-preference-audit-M7Q2.md`
- `evidence/2026-11-01-wua6-policy-inventory-and-transaction-counts-U6M9.md`
- `evidence/2026-11-01-wua6-publishing-http-parity-P8J2.md`
- `evidence/2026-11-01-wua6-standby-secret-removal-no-stepup-S7M2.md`
- `evidence/2026-11-01-wua7-test-db-rebuild-M8Q3.md`
- `evidence/2026-11-01-wua8-static-rp-cell-model-binding-A2V6.md`
- `evidence/2026-11-02-p1-nontransactional-residue-fk-Q4T7.md`
- `evidence/2026-11-02-three-com-static-checks-C0M1.md`
- `evidence/2026-11-03-email-authentication-completion-E4M8.md`
- `evidence/2026-11-03-op-mediated-step-up-unit-1-2-9K4M.md`
- `evidence/2026-11-04-op-step-up-admission-resume-lock-trace-B3F9.md`
- `evidence/2026-11-04-op-step-up-lock-candidate-scan-P8K2.md`
- `evidence/2026-11-04-op-step-up-model-and-mailer-lock-trace-Q9M4.md`
- `evidence/2026-11-04-op-step-up-oidc-init-lock-trace-T4W7.md`
- `evidence/2026-11-04-op-step-up-oidc-purger-lock-order-N8Q4.md`
- `evidence/2026-11-04-op-step-up-op-only-consume-lock-trace-H6Q2.md`
- `evidence/2026-11-04-op-step-up-passkey-removal-A6F2.md`
- `evidence/2026-11-04-op-step-up-secret-receipt-lock-order-M3Q8.md`
- `evidence/2026-11-04-op-step-up-session-limit-resolution-lock-order-S2K5.md`
- `evidence/2026-11-04-op-step-up-signup-finalization-lock-trace-S3J8.md`
- `evidence/2026-11-04-op-step-up-signup-flow-lock-order-V7M2.md`
- `evidence/2026-11-04-op-step-up-social-callback-lock-trace-R6T1.md`
- `evidence/2026-11-04-op-step-up-test-db-repair-J4K8.md`
- `evidence/2026-11-04-signup-cleanup-stale-binding-lock-order-LQ7M.md`
- `evidence/2026-11-05-structure-contact-7M3Q.md`
- `evidence/2026-11-06-handoff-h2-1714-6K2Q.md`
- `evidence/2026-11-06-handoff-h2-org-avatar-7C2M.md`
- `evidence/2026-11-06-public-method-coverage-classification-R4T7.md`
- `evidence/2026-11-06-rails-test-groups-abc-7Q4M.md`
- `evidence/2026-11-07-com-removal-acceptance-7K2P.md`
- `evidence/2026-11-09-governance-route-separation-baseline-G7Q2.md`
- `evidence/2026-11-09-governance-route-separation-cleanup-M6H2.md`
- `evidence/2026-11-09-rails-db-performance-removal-and-route-followups-V8Q3.md`
- `evidence/2026-11-11-governance-round2-R2A7.md`
- `evidence/2026-11-11-surface-hard-reset-V4N8.md`
- `evidence/2026-11-12-completion-claim-lock-uniqueness-U8M3.md`
- `evidence/2026-11-12-database-consistency-baseline-D8K2.md`
- `evidence/2026-11-12-remove-non-governance-databases-R4D8.md`
- `evidence/2026-11-12-rp-step-up-history-and-uniqueness-S9R4.md`

#### plan

- `plans/2026-11-01-wua2-registration-completion-receipt-shape-review.md`
- `plans/2026-11-07-handoff-status.md`
- `plans/2026-11-07-machine-handoff-closure.md`
- `plans/archive/0001-op-rp-separation/acceptance-definitions.md`
- `plans/archive/0001-op-rp-separation/implementation-plan.md`
- `plans/archive/0001-op-rp-separation/implementation-reports.md`
- `plans/archive/0001-op-rp-separation/investigation-history.md`
- `plans/archive/0001-op-rp-separation/planning-discussion.md`
- `plans/archive/0001-op-rp-separation/watchdog-log.md`
- `plans/archive/0002-authentication-cycle-2026-10/acceptance-cases.md`
- `plans/archive/0002-authentication-cycle-2026-10/critical-review-disposition.md`
- `plans/archive/0002-authentication-cycle-2026-10/critical-review.md`
- `plans/archive/0002-authentication-cycle-2026-10/requirements-and-decisions.md`
- `plans/archive/0002-authentication-cycle-2026-10/work-unit-definitions.md`
- `plans/archive/0003-authentication-handoff-work-logs/six-implementation-notes.md`
- `plans/archive/0003-authentication-handoff-work-logs/two-design-work-log.md`
- `plans/archive/0003-authentication-handoff-work-logs/zero-agent-message-board.md`
- `plans/backlog/2026-09-17-integrated-hardening-plan.md`
- `plans/backlog/2026-09-24-integrated-auth-avatar-warp-plan.md`
- `plans/backlog/2026-09-25-avatar-image-and-emergency-credential-decisions.md`
- `plans/backlog/2026-10-18-production-runtime-secret-isolation.md`
- `plans/backlog/2026-10-20-cross-database-atomicity-refactoring.md`
- `plans/backlog/2026-10-20-grant-token-reference-without-fk.md`
- `plans/backlog/2026-10-20-parent-deletion-policy-redesign.md`
- `plans/backlog/2026-10-20-publishing-composite-fk-target-unique-indexes.md`
- `plans/backlog/2026-10-20-required-columns-assigned-after-validation.md`
- `plans/backlog/2026-10-20-uniqueness-validation-vs-database-index.md`
- `plans/backlog/2026-10-22-sign-entry-sentry-implementation.md`
- `plans/backlog/2026-11-03-op-mediated-step-up-standards-alignment.md`
- `plans/backlog/2026-11-04-base-rp-cell-root-token-features.md`
- `plans/backlog/2026-11-06-selector-state-machine-connection.md`
- `plans/backlog/2026-11-07-two-work-unit-handoff-residuals.md`
- `plans/backlog/2026-11-07-visa-rp-logout-revocation-dead-end.md`
- `plans/backlog/cross-database-model-associations-audit.md`
- `plans/backlog/database-improvements.md`
- `plans/backlog/idp-flow-state-machine-unification.md`
- `plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md`
- `plans/backlog/token-lifetime-policy-by-surface-implementation.md`
- `plans/backlog/utm-parameter-adoption-consideration.md`
- `plans/backlog/zenith-placement-candidate-models.md`
- `plans/umaxica-global-open-misty-adleman.md`

#### research

- `research/2026-06-13-security-audit-authentication-authorization.md`
- `research/2026-06-22-codex-google-social-login-cooldown.md`
- `research/2026-06-24-codex-rp-clienttoken-multiplicity-investigation.md`
- `research/2026-06-24-oidc-token-exchange-actor-session-token-audit.md`
- `research/2026-08-29-ceremony-store-diagnosis.md`
- `research/2026-10-20-claude-session-fixation-oidc-result-retry.md`
- `research/2026-10-22-sign-entry-sentry-investigation.md`
- `research/2026-10-22-test-value-audit/duplicates.md`
- `research/2026-10-22-test-value-audit/files.md`
- `research/2026-10-22-test-value-audit/findings.md`
- `research/2026-10-22-test-value-audit/harness.md`
- `research/2026-10-22-test-value-audit/inventory/gait.md`
- `research/2026-10-22-test-value-audit/inventory/rails-adapters.md`
- `research/2026-10-22-test-value-audit/inventory/rails-concerns.md`
- `research/2026-10-22-test-value-audit/inventory/rails-contracts.md`
- `research/2026-10-22-test-value-audit/inventory/rails-controllers-auth.md`
- `research/2026-10-22-test-value-audit/inventory/rails-controllers-base.md`
- `research/2026-10-22-test-value-audit/inventory/rails-controllers-concerns.md`
- `research/2026-10-22-test-value-audit/inventory/rails-controllers-core.md`
- `research/2026-10-22-test-value-audit/inventory/rails-controllers-edit.md`
- `research/2026-10-22-test-value-audit/inventory/rails-controllers-palm.md`
- `research/2026-10-22-test-value-audit/inventory/rails-controllers-root.md`
- `research/2026-10-22-test-value-audit/inventory/rails-controllers-tech.md`
- `research/2026-10-22-test-value-audit/inventory/rails-controllers-warp.md`
- `research/2026-10-22-test-value-audit/inventory/rails-forms.md`
- `research/2026-10-22-test-value-audit/inventory/rails-integration.md`
- `research/2026-10-22-test-value-audit/inventory/rails-jobs.md`
- `research/2026-10-22-test-value-audit/inventory/rails-lib.md`
- `research/2026-10-22-test-value-audit/inventory/rails-mailers.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-a.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-c.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-concerns.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-d.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-e.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-f.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-l.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-m.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-o.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-p.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-publishing.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-r.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-s.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-t.md`
- `research/2026-10-22-test-value-audit/inventory/rails-models-v.md`
- `research/2026-10-22-test-value-audit/inventory/rails-notifiers.md`
- `research/2026-10-22-test-value-audit/inventory/rails-operations.md`
- `research/2026-10-22-test-value-audit/inventory/rails-policies.md`
- `research/2026-10-22-test-value-audit/inventory/rails-queries.md`
- `research/2026-10-22-test-value-audit/inventory/rails-resolvers.md`
- `research/2026-10-22-test-value-audit/inventory/rails-security.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-acme.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-dbsc.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-dpop.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-identity.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-jump_rt.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-oidc.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-org.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-root.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-sign.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-sign_in.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-sign_up.md`
- `research/2026-10-22-test-value-audit/inventory/rails-services-staff_secret_credentials.md`
- `research/2026-10-22-test-value-audit/inventory/rails-tasks.md`
- `research/2026-10-22-test-value-audit/inventory/rails-tooling.md`
- `research/2026-10-22-test-value-audit/inventory/rails-unit.md`
- `research/2026-10-22-test-value-audit/inventory/rails-values.md`
- `research/2026-10-22-test-value-audit/signals.md`
- `research/2026-10-23-passkey-usage-inventory.md`
- `research/app-secret-persistence-shape-proposal.md`
- `research/apple-google-external-authentication-architecture-audit.md`
- `research/implementation/2026-05-30-authentication-controller-surface-extraction.md`
- `research/implementation/2026-06-13-security-audit-finding-01-04.md`
- `research/implementation/2026-06-16-database-consistency-length-validator-gap.md`
- `research/implementation/2026-07-16-simplecov-phase-3.md`
- `research/implementation/2026-07-21-publishing-drop-preference-transport-query-guards.md`
- `research/implementation/2026-08-06-app-sign-out-ceremony-alignment.md`
- `research/implementation/2026-08-10-development-tunnel-access-verification.md`
- `research/implementation/2026-09-03-publishing-media-usage-split.md`
- `research/implementation/2026-09-03-publishing-phase-cde.md`
- `research/implementation/2026-09-04-publishing-management-ui.md`
- `research/implementation/2026-09-04-publishing-twelve-family-encryption.md`
- `research/implementation/2026-09-06-publishing-cms-lifecycle-and-authentication.md`
- `research/implementation/2026-09-06-rails-test-regressions.md`
- `research/implementation/2026-09-06-shrine-fakecloud-attachments.md`
- `research/implementation/2026-09-09-ux-preference-asset-hostname-fixes.md`
- `research/implementation/2026-09-10-publishing-pagy-offset-pagination.md`
- `research/implementation/2026-09-12-edit-publishing-management-surface.md`
- `research/implementation/2026-09-14-refactor-plan-history.md`
- `research/implementation/2026-09-14-test-failure-repairs.md`
- `research/implementation/coverage-batch-1.md`
- `research/implementation/coverage-batch-10.md`
- `research/implementation/coverage-batch-11.md`
- `research/implementation/coverage-batch-13.md`
- `research/implementation/coverage-batch-15.md`
- `research/implementation/coverage-batch-17.md`
- `research/implementation/coverage-batch-18.md`
- `research/implementation/coverage-batch-2.md`
- `research/implementation/coverage-batch-20.md`
- `research/implementation/coverage-batch-21.md`
- `research/implementation/coverage-batch-27.md`
- `research/implementation/coverage-batch-30.md`
- `research/implementation/coverage-batch-36.md`
- `research/implementation/coverage-batch-39.md`
- `research/implementation/coverage-batch-4.md`
- `research/implementation/coverage-batch-5.md`
- `research/implementation/coverage-batch-7.md`
- `research/implementation/coverage-targets-batch-1.md`
- `research/implementation/fakecloud-aws-development-baseline.md`
- `research/implementation/rails-directed-jump-handoffs.md`
- `research/implementation/shrine-s3-object-storage-foundation.md`
- `research/local/2026-10-13-one-candidate-0.10-full-history.md`
- `research/local/2026-10-13-two-candidate-0.10-full-history.md`
- `research/postgresql-association-fk-review.md`
- `research/postgresql-integrity-audit-findings.md`
- `research/postgresql-integrity-audit-matrix.md`
- `research/postgresql-integrity-current-static-inventory.md`
- `research/sign-in-sequence-state-machine.md`

#### runbook

- `docs/runbooks/device-session-token-integrity-rollout.md`
- `docs/runbooks/unified-enforcement-rollout.md`

#### spec

- `specs/authentication-cycle-completion/acceptance.md`
- `specs/authentication-cycle-completion/baseline.md`
- `specs/brakeman-findings-remediation/spec.md`
- `specs/browser-flow-state-cookies/inventory.md`
- `specs/browser-flow-state-cookies/spec.md`
- `specs/cosmos-press-route-ownership/spec.md`
- `specs/database-consistency-remediation/current-findings.md`
- `specs/database-consistency-remediation/cycles.md`
- `specs/database-consistency-remediation/decisions.md`
- `specs/database-consistency-remediation/findings.md`
- `specs/database-consistency-remediation/finite-length-review.md`
- `specs/database-consistency-remediation/foreign-key-review.md`
- `specs/database-consistency-remediation/index-review.md`
- `specs/database-consistency-remediation/missing-index-review.md`
- `specs/database-consistency-remediation/plan.md`
- `specs/database-consistency-remediation/public-id-check-review.md`
- `specs/database-consistency-remediation/public-id-review.md`
- `specs/database-consistency-remediation/spec.md`
- `specs/database-consistency-remediation/unique-index-review.md`
- `specs/global-region-canonicalization/spec.md`
- `specs/governance-database-consistency/spec.md`
- `specs/op-mediated-step-up/contracts/consumer-inventory.md`
- `specs/op-mediated-step-up/contracts/contact-registration-rp-migration-proposal.md`
- `specs/op-mediated-step-up/contracts/lock-order-inventory.md`
- `specs/op-mediated-step-up/contracts/o9-implementation-design.md`
- `specs/op-mediated-step-up/contracts/q1-security-mode-implementation-design.md`
- `specs/op-mediated-step-up/contracts/revision-13-design.md`
- `specs/op-mediated-step-up/review-1.md`
- `specs/op-mediated-step-up/review-3.md`
- `specs/op-mediated-step-up/review-8.md`
- `specs/org-organization-consolidation/inventory.md`
- `specs/org-organization-consolidation/report.md`
- `specs/realm-separated-identifiers-and-dead-history/plan.md`
- `specs/remove-non-governance-databases/spec.md`
- `specs/sign-fqdn-integrated-plan/plan.md`

## Out of scope

- Production, retained/shared physical databases, Queue schema/configuration and external storage resources were not dropped or rebuilt. No surviving migration or schema source is changed by this removal phase.
- Existing ADRs, docs, checklists and diagrams remain unchanged; their stale behavior references are listed above for Claude's handoff.
- The original DatabaseConsistency task remains open. The latest standard checker run reports **zero KEEP findings** after adding exact PostgreSQL JSON expression-index equivalence support; Solid Queue remains outside the evaluation. A separate audit found 98 unvalidated foreign keys and the OperatorChronicle event-18 identity CHECK still admits JSON null/array forms. The former 98 constraints are outside the previously approved 42-constraint slice; the latter requires an authoritative identifier-type decision and migration risk review. See `evidence/2026-11-12-database-consistency-baseline-D8K2.md`, `specs/governance-database-consistency/remaining-foreign-key-validation.md` and `specs/governance-database-consistency/halt-audit-identity-gap.md`.
- Existing development databases still have 14 unapplied migrations from the interrupted consistency work. Reconstruction evidence uses isolated databases and does not imply existing environments were upgraded.
- Workflow inventory application is blocked by the read-only `.github` mount. The prepared patch remains unapplied; this limitation prevents full removal acceptance.

## Latest workflow check

The latest `git apply --check patches/remove-non-governance-workflow-databases.patch` succeeded. `findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS -T .github` reports `/home/global/workspace/.github` mounted from the Governance `.github` ZFS dataset with `ro` options. The process is UID 1000; the earlier remount attempt failed because remount requires superuser privileges. The exact patch remains unapplied. No workflow file or mount was changed, and no privilege or mount restriction was bypassed.

## Latest final acceptance snapshot

Earlier mentions of pending reruns or intermediate suite counts below are chronological checkpoints;
this final snapshot supersedes them where results differ.

HEAD remains `43db4906742db2fb13b238c9ccde378e4e1583b4`; the extensive uncommitted working tree was preserved. Latest checks on this worktree:

- `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test`: **7,657 tests, 51,376 assertions, 0 failures, 0 errors, 0 skips**.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency`: exit **0**, output `No configuration files were provided`, **0 reported KEEP findings**. No checker exclusion or warning suppression was added; Solid Queue remains out of the evaluation.
- `bin/rubocop`: **2,922 files**, no offenses.
- `bundle exec erb_lint --lint-all`: **1,203 files**, no errors; the existing parser/runtime version warning remains.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: exit **0**, 0 errors and 0 security warnings.
- `bun run check`: exit **0** after formatting and correcting typed test fixtures; no CI configuration was changed.
- Latest runtime search of the ten removed abstract record names across `app`, `config`, `lib`, `test` and `db`, and the ten removed connection names in the specified runtime database lists, returned no matches. Intentional historical documentation and negative-test references remain as catalogued above.
- The final fresh `bun run test:coverage` run passed **68 files / 696 tests**, at **100% statements, 99.7% branches (1,021/1,024), 100% functions and 100% lines**. This frontend coverage result does not imply the independent Minitest SimpleCov gates pass; the separate coverage checkpoint records those limits.

Removal acceptance is **incomplete only at the workflow-file edit**: `.github/workflows/ci.yml` still contains the removed connection names because its dataset is mounted read-only. The valid patch remains at `patches/remove-non-governance-workflow-databases.patch`. All removal changes otherwise remain local and uncommitted. No production/shared database or Solid Queue schema was modified.

The original database-improvement task is also still open despite the checker result being clean: 98 other `NOT VALID` foreign keys were not included in the owner-approved set of 42, and the OperatorChronicle exact-identity JSON contract has the unresolved validity gap described in the linked spec. No invalid historical rows were deleted or rewritten.

## Runtime inventory recheck

A fresh `rg` for all ten removed abstract record class names under `app`, `config`, `lib`, `test`, and non-SQL `db` files returned no matches. A targeted connection-name search over `config/database.yml`, `config/ci.rb`, `app/services/health.rb`, and `app/values/rp_cell_binding.rb` also returned no matches. These scoped searches do not supersede the documented historical references or the still-unapplied workflow patch.

## Retired protocol paths and remaining runtime-name references

A new regression first failed because the CSRF route invariant still exempted retired OP and Publishing paths. Removed the obsolete OAuth token/revocation, Apple notification, OP back-channel closure and Publishing path patterns from that test's exception list; retained Base owner API exceptions remain. The regression now checks that those retired paths are not exempt. `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test test/controllers/security/csrf_route_coverage_test.rb test/controllers/csp_violation_reports_controller_test.rb` passed **13 tests, 161 assertions, 0 failures/errors/skips**. RuboCop passed for the invariant test and the two comment-only runtime files. The full suite has not been rerun after this test-only security guard change.

A runtime/config/test search for the removed class and connection names now finds no removed database configuration or class. Remaining names are intentional negative tests for unregistered Publishing storage, an unowned Publishing route and retired RP cells; the new security test names retired paths to prove they are not exempt. Other Publishing mentions are references to the historical cache-policy ADR, which the user asked not to rewrite. The `db/storages_migrate/README.md` still describes former Publishing media ownership and is included in the documentation handoff. Removed outdated nonfunctional comments that listed `search` as a current database or described Publishing/OP services as local back-channel authorities; no HTTP or storage behavior changed.

A subsequent route audit found that all 22 currently routed controllers in the retained server-to-server protocol path families inherit `ActionController::API`. Added a non-vacuous invariant that requires each state-changing route covered by those CSRF exception patterns to use an API controller; it reports a browser controller at the same path instead of silently accepting the exception. The independent scan included all routed actions, while the invariant covers state-changing routes. The CSRF/CSP focused run passed **14 tests, 165 assertions, 0 failures/errors/skips**, and RuboCop passed for the changed test. The full suite was not rerun after this test-only change.

## Contact binding fail-closed prerequisite ordering

`ClientEmail#finalize_binding!` and `ClientTelephone#finalize_binding!` immediately raise `AccessOpDataUnavailableError`, but their omitted `at:` argument previously evaluated `database_now` first. A simulated database clock connection failure therefore produced `ActiveRecord::ConnectionNotEstablished` instead of the explicit Access-unavailable error. Added tests for both concrete public entry points; the initial run had **8 tests, 2 failures**. Their unused optional keyword now defaults to `nil`, preserving the call signature while avoiding the unnecessary database access before the explicit failure. No persisted state or schema is changed.

`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test test/models/access_op_model_boundary_test.rb test/models/client_email_test.rb test/models/client_telephone_test.rb` passed **89 tests, 331 assertions, 0 failures/errors/skips**. RuboCop passed for the two concerns and boundary test. A scoped search found no other immediately raising Access-unavailable methods with `database_now` in their method signature. Full-suite and coverage figures recorded earlier predate this change.

After the contact-boundary change and the CSRF invariant updates, `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test PARALLEL_WORKERS=1 COVERAGE=false bin/rails test` passed **7,649 tests, 51,257 assertions, 0 failures, 0 errors, 0 skips**. Coverage was disabled; the previously reported isolated full-suite coverage result predates these changes and did not meet the repository's minimums.

## Latest static gates

After the contact-boundary and CSRF invariant changes, the requested static commands were rerun against the current dirty worktree, each exiting **0**:

- `bin/rubocop`: **2,919 files**, no offenses.
- `bundle exec erb_lint --lint-all`: **1,203 files**, no errors; the parser warned that it loads Ruby 3.3 syntax while the runtime is Ruby 4.0.9.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: no warnings.
- `bun run check`: passed, including OpenAPI validation and bundle verification.

These checks do not apply the blocked workflow patch or establish that the isolated coverage thresholds pass.
