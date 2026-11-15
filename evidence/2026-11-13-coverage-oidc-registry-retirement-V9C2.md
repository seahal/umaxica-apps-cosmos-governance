# OIDC Registry Dead-Path Retirement and Coverage Revalidation

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had **1,093 changed or untracked paths** before this evidence and specification
update. It already contained extensive uncommitted changes, including earlier changes to the OIDC
registry and test. This slice preserved those surrounding edits and made no commit or push. No
database schema, migration, data, credential, or CI file changed.

## OIDC registry change

The current static first-party RP clients use `private_key_jwt`, and current product callers use
`OidcClientRegistry.authenticate_assertion`. Source searches found no caller for the legacy
`authenticate(client_id, secret_credential)` method or `OidcClientSecretResolver`. The registry also
loaded a shared secret into a client configuration field that current authentication did not use.
Removed the unused public authentication method, its resolver helper and configuration field, and
deleted `app/resolvers/oidc_client_secret_resolver.rb`. Client Secret credential lifecycle code and
owner-side operations remain in place.

Added assertions to the current registry test that a resolved first-party client does not expose a
secret and that the legacy authentication method is not public. The focused test passed. No Red run
is claimed for this dead-path deletion: it had no current product caller, and a synthetic invocation
would not test behavior available through the product. The new assertions were added after the
implementation cleanup and are recorded as Green only.

`rg -n 'OidcClientSecretResolver|OidcClientRegistry\.authenticate\b|resolve_secret_credential' app lib config test`
returned no matches. `authenticate_assertion` remains used by the current owner-boundary callers.

## Verification

| Command                                                                                                                                                                                                                                                                                                                                                                                                                                      | Result                                                                                                                                                                                                                                                                                |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `env -u COVERAGE RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test test/values/oidc_client_registry_test.rb` | **7 tests / 43 assertions / 0 failures / 0 errors / 0 skips**                                                                                                                                                                                                                         |
| `bin/rubocop app/values/oidc_client_registry.rb test/values/oidc_client_registry_test.rb`                                                                                                                                                                                                                                                                                                                                                    | Passed: 2 files, no offenses                                                                                                                                                                                                                                                          |
| `bin/rails zeitwerk:check`                                                                                                                                                                                                                                                                                                                                                                                                                   | Passed: `All is good!`                                                                                                                                                                                                                                                                |
| `COVERAGE=true RUBYOPT=-W0 RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_app_zenith_db,test_org_zenith_db,test_app_setting_db,test_org_setting_db,test_com_setting_db,test_rp_base_app_db,test_rp_base_org_db,test_rp_tech_org_db,test_app_signal_db,test_org_signal_db,test_queue_db,test_storage_db,test_occurrence_db,test_chronicle_db,test_avatar_db,test_primary_db bin/rails test`                                            | Minitest passed: **7,506 tests / 50,227 assertions / 0 failures / 0 errors / 0 skips**. SimpleCov exited 2 on its unchanged thresholds: line **90.46% (30,118/33,293; minimum 98%)**, branch **62.17% (3,508/5,642; minimum 93%)**, and method **85.76% (4,344/5,065; minimum 97%)**. |
| `bun run test:coverage`                                                                                                                                                                                                                                                                                                                                                                                                                      | Passed: **59 files / 588 tests**; statements **100% (1,072/1,072)**, branches **100% (824/824)**, functions **100% (360/360)**, and lines **100% (1,045/1,045)**.                                                                                                                     |
| `git diff --check`                                                                                                                                                                                                                                                                                                                                                                                                                           | Passed                                                                                                                                                                                                                                                                                |

The full Rails run printed existing `AccessOpDataUnavailableError` exceptions from concurrency
worker threads. Minitest recorded no failures or errors. No coverage threshold, exclusion, or source
ignore annotation changed.

## Public/protected runtime inventory

The current Rails runtime method inventory was joined by source identity to all 17 SimpleCov worker
resultsets using `SimpleCov::Combine::MethodsCombiner`. The resulting **2,574** rows are:

| Visibility         |      Rows |   Reached |  Missed | No one-to-one location | Same-line name mismatch |
| ------------------ | --------: | --------: | ------: | ---------------------: | ----------------------: |
| Public instance    |     1,603 |     1,348 |     101 |                    135 |                      19 |
| Public class       |       910 |       894 |      14 |                      0 |                       2 |
| Protected instance |        61 |        49 |      12 |                      0 |                       0 |
| **Total**          | **2,574** | **2,291** | **127** |                **135** |                  **21** |

Compared with the previous 128 missed method identities by source path and method name, **127 are
unchanged, zero new misses appeared, and `OidcClientRegistry.authenticate` was removed**. The 103
controller action bodies remain unreachable behind the explicit unavailable Access owner API; the
HTTP entrypoints retain their tested fail-closed responses. The other 24 misses remain in the
previously documented policy, generated-accessor, maintenance/configuration, or no-current-caller
categories. Their current identities are `RpPrincipal#policy_class`; `CoreAppClientBridge` and
`CoreOrgOperatorBridge` each expose `core_default_client_id?`, `core_default_audience?`, and
`core_default_host?`; the seven legacy `ApplicationPolicy` hooks (`organization`, `jwt_subject`,
`operator?`, `operator_or_manager?`, `can_edit?`, `can_view?`, and `can_contribute?`);
`OperatorTelephonePublicIdBackfillOperation.call`; `OrgIamOwnerMutationOperation.grant` and
`.revoke`; `ArchitectureBaseline.write`; `JitSecurityJwtJwksService.normalized_public_jwk`;
`JitSecurityTurnstileConfig.stealth_site_key`; `Umaxica::TestEnvironment::DatabaseSafety.report`;
`Umaxica::Valkey::ResponsibilityUrls.require_url`; and `Umaxica::Valkey::Settings#performance` and
`#[]`. Their caller and reachability dispositions are detailed in the earlier audit linked below.
The current joined inventory is temporary output at
`tmp/coverage-task/public-protected-joined-after-oidc-retirement-2026-11-13.json`.

The older L6N2 evidence's statement that `CredentialDeletionFinalizer.register` had no application
caller is superseded: J8V4 recorded the real `BrowserRpAuthentication` caller and the passing
exception-response middleware test. The missing application writer for
`ClientContactAuditOutbox.record_preferences_changed!` remains an unresolved contract discrepancy.
The 135 rows without a one-to-one instrumented location and 21 same-line name mismatches are not
counted as reached.

## Completion status

- Vitest's 99% gates are met at 100% across all reported dimensions.
- The full Rails Minitest run has zero test failures, but SimpleCov's unchanged aggregate gates are
  not met.
- The runtime inventory has no new missed method; remaining misses are dispositioned and Access-
  owned success bodies are not claimed as covered.
- The preference audit API still lacks an application writer. The aggregate SimpleCov gates remain
  an open acceptance item.
- No schema, database, credentials, or CI configuration was changed; no commit or push was made.
