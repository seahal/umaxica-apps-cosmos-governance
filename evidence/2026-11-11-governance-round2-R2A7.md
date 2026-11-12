# Governance surface cleanup, round 2

Date: 2026-11-11

## Revision and worktree

- `git rev-parse HEAD`: `43db4906742db2fb13b238c9ccde378e4e1583b4`.
- No commit was created. The checks ran against a worktree with broad uncommitted and untracked changes already present; results describe that worktree, not a clean checkout. The index was temporarily used for the OpenAPI bundle check and was cleared afterward.
- No database or table was dropped. No migration was deleted. The `db/*structure.sql` files have no diff from HEAD: 26 near-empty snapshots discovered during test repair were restored from HEAD. This restores schema definitions; it does not alter a database.

## Follow-up audit — non-`.github` completion

The user's follow-up explicitly excluded `.github`; no `.github` file was changed in this audit. The follow-up rechecked the current routes, controller namespaces, non-historical host references, environment-variable names, OpenAPI descriptions and bundles, dead runtime code, and the required verification gates. It removed the remaining stale foreign-host fixtures and API error-test assumptions, the unused external-sign-in value class, and stale DBSC wording from the current OpenAPI descriptions. It also marked the UI normalization ledger as historical and removed its retired Auth-host command. The unindexed Jump checklist now states that its pre-reset 20-edge graph is historical and that the current Rails return graph is empty.

The app/config/env scan found no foreign-surface URL variable names in `.env*`, Rails config or compose inputs, and found only Base com `*_CORPORATE` identifiers in source. Routes and controller namespaces contain no foreign controllers or social callback paths. `config/routes/` remains the eight retained files listed above. The test-environment route table audit counted 442 route objects (439 host-constrained, 3 unconstrained), with zero foreign controller namespaces and zero social callback paths; a final `bin/rails routes` rerun exited successfully and the development inventory remains the 453-object inventory above.

One non-`.github` residual remains: `.devcontainer/compose.yaml` still declares retired host aliases. The file is on a read-only mount (`findmnt` reports `ro`), and the original task instruction also said not to touch `.devcontainer/**`; the file was inspected but not changed. Its existing uncommitted diff was preserved. This residual prevents claiming every non-`.github` configuration surface is complete.

After aligning stale Jump-return success expectations with the intentionally empty local return graph, the full Rails suite ran 9,782 tests with 63,754 assertions, 219 failures, 48 errors and no skips. Compared with the immediately preceding run (9,794 tests, 63,775 assertions, 247 failures), 28 Jump-return failure identifiers were resolved and no new failure identifier appeared. The follow-up also fixed one unauthenticated Base route test that parsed an absent redirect, resolving one `NoMethodError`; no new error identifier appeared. Error-class counts are: 22 `ActiveRecord::RecordNotUnique`, 9 `RuntimeError`, 8 `KeyError`, 4 `AvatarOwnershipTransfers::InvalidTransfer`, 3 `ArgumentError` and 2 `NoMethodError`; foreign-key, missing-constant, missing-translation and missing-file error counts remain zero.

## 1. Route and controller inventory

The application route inventory contains 453 route objects: 444 host-constrained and 9 unconstrained. Hostnames are represented by labels below; configured host values are omitted.

| Owned surface / host label | Route objects |
| --- | ---: |
| Base service (`base_service`) | 178 |
| Base com (`base_com`) | 61 |
| Base org (`base_staff`) | 189 |
| Tech org (`tech_staff`) | 10 |
| Mission | 1 mount |
| Flipper | 1 mount |
| Blazer | 1 mount |
| PgHero | 1 mount |
| Swagger | 2 mounts |
| Coverband | 0 in this runtime; its owned route file remains behind the runtime guard |
| Unknown-host 404 fallback | 1 |
| Rails/Inertia development endpoints | 8 unconstrained framework routes |

The 61 Base com routes were retained unchanged. Among writable application and host-configuration files, the only retained corporate/com URL configuration is Base com, needed by those routes. All other foreign surface route objects and corporate host handling are absent from the route inventory. It contains no Auth, Visa, Core, Warp, Palm, Edit, Docs, News, Help, Info, Guid or Performance host, and no social/OAuth callback route. `config/routes/` contains `base.rb`, `tech.rb`, and the six operator-tool route files only. Coverband has zero route objects in this `bin/rails routes` runtime because its Rack application was not loaded by its guard. Rails and Inertia development routes are framework endpoints, not product surfaces.

Current controller files: Base 199 (OWN: app, org and com), Tech 12 (OWN: org), shared concerns 112, root `ApplicationController` 1, and `UnknownHostsController` 1. The shared concern directory includes an already-untracked browser RP request guard; it is counted as present and was not removed. Foreign/retired namespace counts from the pre-cleanup inventory were Auth 119, Visa 61, Core 64, Warp 61, Palm 21, Edit 53, Docs 33, News 33, Help 33, Info 33 and Guid 11; these namespaces are removed. Performance had a route file but no controller namespace. The mounted operator tools are engines, not controller namespaces.

The full route-object inventory and separately expanded engine routes are appended below.

## 2. Deletions and configuration

- Deleted the 12 foreign/retired route files and their route blocks, controllers, views, helpers, foreign-only concerns and callers. Removed foreign host entries and documentation references from writable files.
- The tracked deletion summary in this already-dirty worktree includes 598 namespaced controller files (Auth 119, Base-retired 70, Core 64, Docs 33, Edit 53, Guid 11, Help 33, Info 33, News 33, Palm 21, Tech-retired 6, Visa 61, Warp 61), 113 controller concerns, 88 views, 23 adapters, 55 services, 76 operations, 49 values, and 18 policies. Test deletions include 269 controller, 180 model, 177 integration, 124 service and 88 operation tests, plus smaller categories. These are worktree totals across the supplied round-1 starting state, not a claim that every deletion was authored in the final round-2 turn.
- Removed social sign-in provider setup, callback code/routes/views/tests, and the five unused OmniAuth gems: `omniauth`, `omniauth-apple`, `omniauth-google-oauth2`, `omniauth_openid_connect`, and `omniauth-rails_csrf_protection`.
- Removed the local authorization-code Valkey store, OTP verification failure-budget models and callers, and automatic database selector/resolver setup. `app/services/valkey/auth_state/` now contains only `opaque_admission_store.rb`.
- Removed two model files expressly authorized in Part B1: `email_otp_verification_failure_budget.rb` and `telephone_otp_verification_failure_budget.rb`. No other model or migration was deleted.
- Removed 416 stale sign-in, sign-up, step-up, social-provider, controller-label and provider-view translation leaves from each locale bundle and pruned the empty locale nodes left by those removals. A final locale-tree scan found no remaining empty YAML nodes. This includes the Google provider branch and 13 unreferenced old email/telephone registration, sign-in limitation, sign-out and v1 passkey view labels. The locale-key assertion no longer expects the six absent Help-surface keys, two retired `sign.org.in` keys or the removed Google setting. Twelve Apple/Google social event labels remain in shared and app/org activity-event namespaces so historical identity audit entries stay readable.
- Removed URL and feature environment-variable names associated with foreign surfaces from writable `.env*`, application configuration and compose files. Variable names are listed in the appendix; no environment values are recorded.
- **CI configuration blocker:** `.github/workflows/ci.yml` is not writable in this environment (`test -w` returned false); an earlier edit attempt was rejected by the read-only filesystem. It still contains 46 foreign/configuration `*_URL` keys, listed below. No values were read into this report. This leaves CI workflow text cleanup incomplete. `AUTH_STATE_REDIS_URL` is among those names and has no remaining application/config reader.
- No `.devcontainer/**`, credentials, backlog, plan or ADR files were changed during this round. Existing worktree changes in those areas were preserved.
- Follow-up scope note: `.github` is excluded by the user's latest instruction, so its earlier observation is retained as history and is not part of the non-`.github` completion claim. The read-only `.devcontainer/compose.yaml` residual is described above.
- The unused `ExternalSignIn::NormalizedAuthResult` definition was removed after a caller scan found no app, config, lib or test consumer.

## 3. Dead-code follow-up and retained boundary code

The authorization-code store and both OTP failure-budget models were deleted. `opaque_admission_store.rb` remains because active Base admission and identity flows call it: `BaseAuthAdmissionCoordinator`, `IdentityPasskeyRegistrationFinalCommitter`, `IdentityStepUpCeremonyFreshnessCommitter`, and `IdentityTotpEnrollmentFinalCommitter`. The Base step-up marker adapter/concern also remains; those passkey, TOTP and freshness committers still use the marker. These are active Base flow callers, not Auth/Visa endpoints.

No automatic replica selection remains. The remaining explicit `connected_to(role: :reading)` calls are listed in §4. No tables or databases were dropped, and all structure snapshots match HEAD after restoring their missing definitions.

## 4. Database and model report

Database classification uses an exact-constant scan of application and test code plus loaded Active Record association reflection. It is an inventory, not proof against dynamic constantization or reflection. The detailed 765-concrete-app-model report follows this summary.

| Abstract record database | Classification | Basis |
| --- | --- | --- |
| `app_setting`, `app_signal`, `app_zenith`, `avatar`, `chronicle`, `com_setting`, `occurrence`, `op_base_app`, `op_base_org`, `org_setting`, `org_signal`, `org_zenith`, `publishing`, `rp_base_app`, `rp_base_org`, `rp_tech_org` | USED | Concrete models have non-model callers; one example caller per directly referenced model appears in the detailed report. |
| `rp_core_app`, `rp_core_org`, `rp_edit_org`, `rp_palm_app`, `rp_warp_app`, `rp_warp_org` | ONLY-VIA-MODELS | Remaining references are model associations or tests; no direct non-model app caller was found. Models and migrations remain in this task. |
| `primary` | USED | Rails framework models and mounted engine models use the primary connection (Action Text, Active Storage, Blazer and Noticed). |
| `queue` | USED | Solid Queue models and its recurring-job configuration use this database. |
| `search` | UNUSED | `SearchRecord` has no concrete app model or scanned caller. |
| `storage` | UNUSED | No abstract `*Record` or loaded model maps to it in this application inventory. |

App abstract record mapping: `ApplicationRecord` → `primary`; `SearchRecord` → `search`; `AppSettingRecord` → `app_setting`; `AppSignalRecord` → `app_signal`; `AppPrincipalRecord`, `AppRpRecord`, `AppZenithRecord` → `app_zenith`; `AvatarRecord` → `avatar`; `ChronicleRecord` → `chronicle`; `ComSettingRecord` → `com_setting`; `OccurrenceRecord` → `occurrence`; `OpBaseAppRecord` → `op_base_app`; `OpBaseOrgRecord` → `op_base_org`; `OrgSettingRecord` → `org_setting`; `OrgSignalRecord` → `org_signal`; `OrgPrincipalRecord`, `OrgRpRecord`, `OrgZenithRecord` → `org_zenith`; `PublishingRecord` → `publishing`; and the `RpBaseAppRecord`, `RpBaseOrgRecord`, `RpCoreAppRecord`, `RpCoreOrgRecord`, `RpEditOrgRecord`, `RpPalmAppRecord`, `RpTechOrgRecord`, `RpWarpAppRecord`, and `RpWarpOrgRecord` classes map to their correspondingly named `rp_*` databases. Framework models add 13 loaded primary models and 13 Solid Queue models on `queue`; `storage` had none loaded.

Framework abstract records: Action Text, Active Storage, Blazer and Noticed inherit the primary connection; `SolidQueue::Record` maps to `queue`. Concrete framework/engine model classes loaded in this scan: primary — `ActionText::EncryptedRichText`, `ActionText::RichText`, `ActiveStorage::Attachment`, `ActiveStorage::Blob`, `ActiveStorage::VariantRecord`, `Blazer::Audit`, `Blazer::Check`, `Blazer::Dashboard`, `Blazer::DashboardQuery`, `Blazer::Query`, `Blazer::Upload`, `Noticed::Event`, `Noticed::Notification`; queue — `SolidQueue::Batch`, `SolidQueue::BatchExecution`, `SolidQueue::BlockedExecution`, `SolidQueue::ClaimedExecution`, `SolidQueue::FailedExecution`, `SolidQueue::Job`, `SolidQueue::Pause`, `SolidQueue::Process`, `SolidQueue::ReadyExecution`, `SolidQueue::RecurringExecution`, `SolidQueue::RecurringTask`, `SolidQueue::ScheduledExecution`, `SolidQueue::Semaphore`.

Remaining reading-role call sites:

- `app/queries/sign_up_stuck_registration_report_query.rb:223`
- `app/controllers/concerns/base_preference_actor_projection.rb:63`
- `app/controllers/concerns/preference_browser_state_reader.rb:41, 87, 115`
- `app/controllers/concerns/preference_transport.rb:89`
- `test/integration/solid_infrastructure_test.rb:49`
- `test/services/credential_security_transition_test.rb:360, 386`
- `test/models/flow_expiry_commit_test.rb:37`
- `test/models/security_consumed_jti_test.rb:30`
- `test/controllers/concerns/authentication/audit_writer_test.rb:198, 211, 262`

## 5. Report-only Base controller classification (B4)

Eighty-eight surviving Base app/org controller files were classified without editing those controller files:

- **(a) Future relying-party boundary, 4:** app/org `pre_access` and `full_access` controllers. They are currently unrouted and can define the Base RP boundary when Access sign-in is reconnected.
- **(b) Base-owned identity data management, 73:** accounts, credentials, profiles, sessions, privacy/withdrawal records, organizations, roles and preferences. Secret issuance/presentation here is credential lifecycle data, not OIDC authorization-code or token issuance.
- **(c) Access ceremony/provider candidates, 11:** verification cancellation/completion/setup, withdrawal session re-entry, and app/org JWKS controllers. They remain unchanged because B4 is report-only; the full file list is below.

The detailed B4 file list follows this report.

## 6. Test baseline and error classification

The recorded clean-HEAD baseline was 10,379 runs, 356 failures and 1,732 errors; the post-hard-reset baseline was 10,150 runs, 252 failures and 1,588 errors. This round's post-removal run before restoring structure snapshots was 9,857 runs, 228 failures and 1,157 errors. The prior hard-reset report records 1,492 `ActiveRecord::InvalidForeignKey`, 94 `NameError`, and 77 `I18n::MissingTranslationData` errors on clean HEAD, and 1,449 foreign-key plus 87 `NameError` errors in an earlier current-worktree run. A filtered scan of this round's intermediate output found 1,111 foreign-key exception headers; trace output includes nested worker frames, so that header count is not one-to-one with the Minitest error summary. The test work identified 26 `db/*structure.sql` files replaced by identical near-empty 448-byte snapshots, with 907 table definitions and 854 sequences absent. Restoring those snapshots eliminated the remaining `ActiveRecord::InvalidForeignKey` class from the test run. The final post-fix run is recorded in §8.

Error-cause classification:

- **Fixture/table and foreign-key family:** the intermediate run had about 1.1k foreign-key exception headers (the run total was 1,157 errors). The missing schema definitions in the near-empty snapshots explain this family; restoring the snapshots removed it without changing database data, constraints, migrations or test foreign-key checks.
- **Fixture load order:** no separate fixture-order error remained identifiable in the final run; final `ActiveRecord::InvalidForeignKey` count is zero.
- **Missing constants:** the final run has no `NameError` errors. Foreign-only tests and references to removed constants were deleted or repaired; the obsolete token-exchange invariant test was removed after its implementation was deleted.
- **Missing translations:** the final run has no `I18n::MissingTranslationData` exception. One stale locale guard expected deleted Help keys, the retired `sign.org.in` sign-in keys, and removed Google provider settings; its expectations now cover retained keys only. The locale bundles no longer contain those foreign keys.
- **Remaining errors:** the final run has 22 `ActiveRecord::RecordNotUnique`, 9 `RuntimeError`, 8 `KeyError`, 4 `AvatarOwnershipTransfers::InvalidTransfer`, 3 `ArgumentError`, and 2 `NoMethodError` errors. Exact test identifiers are appended. One unauthenticated Base route test error was resolved; no new error identifier appeared, and the 48 remaining error identifiers were present in the preceding run. The final run has zero `ActiveRecord::InvalidForeignKey`, `NameError`, `I18n::MissingTranslationData`, or `Errno::ENOENT` errors. The first stale-locale cleanup removed one failure ID relative to the preceding 248-failure run. The locale-subtree cleanup and Jump test repair introduced no new IDs; a later correction to the unauthenticated rotation test resolved one error ID. The original clean-HEAD test log did not preserve a complete per-test identifier set, so individual attribution to that historical baseline is not claimed.

The prior hard-reset evidence confirms the four `Base::App::AccountsControllerTest` behavior failures and five `BaseIdentitySessionsPresentationTest` failures were already present on clean HEAD. Their current identifiers are listed separately below. The other 210 current failures are listed but are not all claimed as pre-existing: the original clean-HEAD run did not retain a complete per-test identifier set and the suite composition changed. Sign-in and RP admission failures are consistent with the owner-approved Auth/Visa disconnection; that broader attribution is an inference, not per-test proof.

Before this follow-up, a failure-output marker scan classified 148 of 247 failures as redirect/admission or authentication/authorization response mismatches, consistent with the accepted sign-in disconnection; this is an inference from failure output, not per-test proof. After resolving the 28 stale Jump-return expectations, the 219 remaining failures include those broader response mismatches and other assertions; except for the nine clean-HEAD identifiers above, they remain unclassified against the original baseline.

Owner-approved behavior: local Auth/Visa URL configuration is removed and Base/Tech OIDC sign-in remains disconnected; sign-in breakage is accepted for this task. It is not treated as an OIDC provider workflow.

## 7. Kept items that look foreign

- Base `pre_access`/`full_access` controllers remain as future RP boundary code (unrouted); B4 did not authorize edits.
- Base verification and withdrawal-session ceremony/provider candidates remain only because B4 is report-only. Their future removal/relocation needs its own accepted scope.
- The Base-owned secret credential and issuance/presentation data surfaces remain because they manage identity credentials; they do not issue OIDC authorization codes or tokens.
- Twelve Apple/Google/social event labels remain in identity activity locales to render historical audit entries; they do not enable provider sign-in.
- Avatar ownership, transfer and avatar social-graph behavior remain as owned identity/profile features; social sign-in code and external provider adapters were removed.
- The six operator tools and their route files remain because Mission, Flipper, Blazer, PgHero, Coverband and Swagger are explicitly owned surfaces.
- Six `rp_*` databases with only model/test references remain because this task forbids model and migration cleanup (apart from the two explicitly named OTP budget models).

Security boundary review: the route inventory contains no Auth/Visa issuer surface or social callback, and the explicit unknown-host route remains a 404 boundary. This cleanup did not move or reorder authentication, authorization, CSRF, rate-limit or final transaction writers. The one dependent flow repair changes the second-passkey gate's destination from a deleted passkey route to Base verification setup; its test covers the zero-passkey redirect and the existing one/two/three-passkey mutation boundary. No cross-surface credentials or state were added.

## 8. Verification

| Check | Result |
| --- | --- |
| `bin/rails zeitwerk:check` | Passed: `All is good!` |
| `bin/rails routes` | Passed; 453 application route objects inventoried, plus separately expanded engine routes. |
| `bin/rubocop` | Passed: 3,561 files inspected, no offenses after correcting one extra blank line exposed by the dead-code removal. |
| `bundle exec erb_lint --lint-all` | Passed: 1,207 files, no errors. |
| `bundle exec i18n-tasks missing` | Passed: no missing translations. |
| `bin/rails test test/unit/i18n/runtime_default_cleanup_test.rb` | Passed: 1 run, 32 assertions, no failures/errors. |
| `bun run check` | Passed: format, lint, typecheck, dead-code check, OpenAPI lint and temp-directory bundle comparison; no Redocly warnings. It did not stage files. |
| `bin/rails test` | Red: final run 9,782 runs, 63,754 assertions, 219 failures, 48 errors, 0 skips. It resolves 28 stale Jump-return failure IDs; no new failure IDs; 48 remaining error IDs were already present; one was resolved and none were added. |
| OpenAPI bundle | `bun run openapi:bundle`, `bun run openapi:lint` and `bundle exec ruby scripts/verify_openapi_bundles.rb` passed after the DBSC description cleanup. |
| `git diff --check` | Passed after final edits. |
| Database/migration safety | `git diff -- db` empty; zero deleted migrations; no database or table drops. |

The full route inventory, engine route expansion, controller classification, removed/remaining environment variable names, detailed model references and sanitized test identifiers follow.


## Environment variable names removed

Names below are identifiers only; no values are recorded. Lists are computed from deleted assignments/references minus identifiers re-added in the same diff.

`.env*` assignment names (70):

- `PRIVATE_AUTH_CORPORATE_URL`
- `PRIVATE_AUTH_SERVICE_URL`
- `PRIVATE_AUTH_STAFF_URL`
- `PRIVATE_BASE_DEVELOPER_URL`
- `PRIVATE_BASE_NETWORK_URL`
- `PRIVATE_BLAZER_URL`
- `PRIVATE_CORE_CORPORATE_URL`
- `PRIVATE_CORE_DEVELOPER_URL`
- `PRIVATE_CORE_SERVICE_URL`
- `PRIVATE_CORE_STAFF_URL`
- `PRIVATE_COVERBAND_URL`
- `PRIVATE_DOCS_CORPORATE_URL`
- `PRIVATE_DOCS_SERVICE_URL`
- `PRIVATE_DOCS_STAFF_URL`
- `PRIVATE_EDIT_STAFF_URL`
- `PRIVATE_FLIPPER_URL`
- `PRIVATE_GUID_SERVICE_URL`
- `PRIVATE_HELP_CORPORATE_URL`
- `PRIVATE_HELP_SERVICE_URL`
- `PRIVATE_HELP_STAFF_URL`
- `PRIVATE_INFO_CORPORATE_URL`
- `PRIVATE_INFO_SERVICE_URL`
- `PRIVATE_INFO_STAFF_URL`
- `PRIVATE_MISSION_URL`
- `PRIVATE_NEWS_CORPORATE_URL`
- `PRIVATE_NEWS_SERVICE_URL`
- `PRIVATE_NEWS_STAFF_URL`
- `PRIVATE_PALM_SERVICE_URL`
- `PRIVATE_PERFORMANCE_URL`
- `PRIVATE_PGHERO_URL`
- `PRIVATE_SWAGGER_URL`
- `PRIVATE_VISA_CORPORATE_URL`
- `PRIVATE_VISA_SERVICE_URL`
- `PRIVATE_VISA_STAFF_URL`
- `PUBLIC_AUTH_CORPORATE_URL`
- `PUBLIC_AUTH_SERVICE_URL`
- `PUBLIC_AUTH_STAFF_URL`
- `PUBLIC_BASE_DEVELOPER_URL`
- `PUBLIC_BLAZER_URL`
- `PUBLIC_CORE_CORPORATE_URL`
- `PUBLIC_CORE_DEVELOPER_URL`
- `PUBLIC_CORE_SERVICE_URL`
- `PUBLIC_CORE_STAFF_URL`
- `PUBLIC_COVERBAND_URL`
- `PUBLIC_DOCS_CORPORATE_URL`
- `PUBLIC_DOCS_SERVICE_URL`
- `PUBLIC_DOCS_STAFF_URL`
- `PUBLIC_EDGE_CORPORATE_URL`
- `PUBLIC_EDGE_SERVICE_URL`
- `PUBLIC_EDGE_STAFF_URL`
- `PUBLIC_EDIT_STAFF_URL`
- `PUBLIC_FLIPPER_URL`
- `PUBLIC_GUID_SERVICE_URL`
- `PUBLIC_INFO_CORPORATE_URL`
- `PUBLIC_INFO_SERVICE_URL`
- `PUBLIC_INFO_STAFF_URL`
- `PUBLIC_MISSION_URL`
- `PUBLIC_PALM_SERVICE_URL`
- `PUBLIC_PERFORMANCE_URL`
- `PUBLIC_PGHERO_URL`
- `PUBLIC_STATUS_URL`
- `PUBLIC_SWAGGER_URL`
- `PUBLIC_VISA_CORPORATE_URL`
- `PUBLIC_VISA_SERVICE_URL`
- `PUBLIC_VISA_STAFF_URL`
- `PUBLIC_WARP_CORPORATE_URL`
- `PUBLIC_WARP_SERVICE_URL`
- `PUBLIC_WARP_STAFF_URL`
- `RAILS_PERFORMANCE_ENABLED`
- `RAILS_PERFORMANCE_USERNAME`

Root compose foreign URL interpolation names removed (0):

No foreign URL interpolation name was present in the root compose diff.

Deleted app/config/lib ENV-reader names in the URL/auth/social/performance groups (39):

- `GUID_SERVICE_URL`
- `ORG_SIGN_UP_DIRECT_MESSAGE_URL`
- `PRIVATE_AUTH_SERVICE_URL`
- `PRIVATE_AUTH_STAFF_URL`
- `PRIVATE_BASE_DEVELOPER_URL`
- `PRIVATE_BASE_NETWORK_URL`
- `PRIVATE_BLAZER_URL`
- `PRIVATE_CORE_CORPORATE_URL`
- `PRIVATE_CORE_DEVELOPER_URL`
- `PRIVATE_CORE_NETWORK_URL`
- `PRIVATE_CORE_SERVICE_URL`
- `PRIVATE_CORE_STAFF_URL`
- `PRIVATE_COVERBAND_URL`
- `PRIVATE_EDIT_STAFF_URL`
- `PRIVATE_FLIPPER_URL`
- `PRIVATE_GUID_SERVICE_URL`
- `PRIVATE_MISSION_URL`
- `PRIVATE_PERFORMANCE_URL`
- `PRIVATE_PGHERO_URL`
- `PRIVATE_SWAGGER_URL`
- `PUBLIC_AUTH_CORPORATE_URL`
- `PUBLIC_AUTH_SERVICE_URL`
- `PUBLIC_AUTH_STAFF_URL`
- `PUBLIC_BASE_DEVELOPER_URL`
- `PUBLIC_BLAZER_URL`
- `PUBLIC_CORE_DEVELOPER_URL`
- `PUBLIC_COVERBAND_URL`
- `PUBLIC_EDIT_STAFF_URL`
- `PUBLIC_FLIPPER_URL`
- `PUBLIC_GUID_SERVICE_URL`
- `PUBLIC_MISSION_URL`
- `PUBLIC_PERFORMANCE_URL`
- `PUBLIC_PGHERO_URL`
- `PUBLIC_SWAGGER_URL`
- `PUBLIC_VISA_CORPORATE_URL`
- `PUBLIC_VISA_SERVICE_URL`
- `PUBLIC_VISA_STAFF_URL`
- `RAILS_PERFORMANCE_ENABLED`
- `SOCIAL_AUTH_CEREMONY_HMAC_KEY`

Base com retained URL identifiers: `PRIVATE_BASE_CORPORATE_URL`, `PUBLIC_BASE_CORPORATE_URL`.

Read-only CI workflow foreign/configuration URL identifiers still present (46):

- `AUTH_STATE_REDIS_URL`
- `PRIVATE_AUTH_CORPORATE_URL`
- `PRIVATE_AUTH_SERVICE_URL`
- `PRIVATE_AUTH_STAFF_URL`
- `PRIVATE_CORE_CORPORATE_URL`
- `PRIVATE_CORE_DEVELOPER_URL`
- `PRIVATE_CORE_SERVICE_URL`
- `PRIVATE_CORE_STAFF_URL`
- `PRIVATE_DOCS_CORPORATE_URL`
- `PRIVATE_DOCS_SERVICE_URL`
- `PRIVATE_DOCS_STAFF_URL`
- `PRIVATE_EDIT_STAFF_URL`
- `PRIVATE_HELP_CORPORATE_URL`
- `PRIVATE_HELP_SERVICE_URL`
- `PRIVATE_HELP_STAFF_URL`
- `PRIVATE_INFO_CORPORATE_URL`
- `PRIVATE_INFO_SERVICE_URL`
- `PRIVATE_INFO_STAFF_URL`
- `PRIVATE_NEWS_CORPORATE_URL`
- `PRIVATE_NEWS_SERVICE_URL`
- `PRIVATE_NEWS_STAFF_URL`
- `PRIVATE_PALM_SERVICE_URL`
- `PRIVATE_PERFORMANCE_URL`
- `PUBLIC_AUTH_CORPORATE_URL`
- `PUBLIC_AUTH_SERVICE_URL`
- `PUBLIC_AUTH_STAFF_URL`
- `PUBLIC_CORE_CORPORATE_URL`
- `PUBLIC_CORE_DEVELOPER_URL`
- `PUBLIC_CORE_SERVICE_URL`
- `PUBLIC_CORE_STAFF_URL`
- `PUBLIC_DOCS_CORPORATE_URL`
- `PUBLIC_DOCS_SERVICE_URL`
- `PUBLIC_DOCS_STAFF_URL`
- `PUBLIC_EDGE_CORPORATE_URL`
- `PUBLIC_EDGE_SERVICE_URL`
- `PUBLIC_EDGE_STAFF_URL`
- `PUBLIC_EDIT_STAFF_URL`
- `PUBLIC_GUID_SERVICE_URL`
- `PUBLIC_INFO_CORPORATE_URL`
- `PUBLIC_INFO_SERVICE_URL`
- `PUBLIC_INFO_STAFF_URL`
- `PUBLIC_PALM_SERVICE_URL`
- `PUBLIC_PERFORMANCE_URL`
- `PUBLIC_WARP_CORPORATE_URL`
- `PUBLIC_WARP_SERVICE_URL`
- `PUBLIC_WARP_STAFF_URL`

## Complete route-object inventory

## Route inventory by host constraint

Rails application route objects: 453. Mounted engines count once per mount. The inventory omits configured host values. `bin/rails routes` also expands built-in engine routes separately.

Host-constrained objects: 444; unconstrained objects: 9.

### base_service — 178 route objects

- `GET /` → `base/app/roots#index` [base_app_root]
- `GET /welcome(.:format)` → `base/app/welcomes#show` [base_app_welcome]
- `GET /dashboard/avatar_image(.:format)` → `base/app/dashboard_avatar_images#show` [base_app_dashboard_avatar_image]
- `GET /dashboard(.:format)` → `base/app/roots#show` [base_app_dashboard]
- `GET /selector(.:format)` → `base/app/selectors#show` [base_app_selector]
- `PATCH /selector(.:format)` → `base/app/selectors#update`
- `PUT /selector(.:format)` → `base/app/selectors#update`
- `GET /switcher(.:format)` → `base/app/switchers#show` [base_app_switcher]
- `PATCH /switcher(.:format)` → `base/app/switchers#update`
- `PUT /switcher(.:format)` → `base/app/switchers#update`
- `GET /billings(.:format)` → `base/app/billings#index` [base_app_billings]
- `GET /secrets(.:format)` → `base/app/secrets#index` [base_app_secrets]
- `POST /secrets(.:format)` → `base/app/secrets#create`
- `GET /secrets/new(.:format)` → `base/app/secrets#new` [new_base_app_secret]
- `GET /secrets/:id/edit(.:format)` → `base/app/secrets#edit` [edit_base_app_secret]
- `GET /secrets/:id(.:format)` → `base/app/secrets#show` [base_app_secret]
- `PATCH /secrets/:id(.:format)` → `base/app/secrets#update`
- `PUT /secrets/:id(.:format)` → `base/app/secrets#update`
- `DELETE /secrets/:id(.:format)` → `base/app/secrets#destroy`
- `POST /secret_issuances/:id/reattempt(.:format)` → `base/app/secret_issuances#reattempt` [reattempt_base_app_secret_issuance]
- `POST /secret_issuances/:secret_issuance_id/presentation(.:format)` → `base/app/secret_presentations#create` [base_app_secret_issuance_presentation]
- `GET /secret_issuances/:id(.:format)` → `base/app/secret_issuances#show` [base_app_secret_issuance]
- `PATCH /secret_issuances/:id(.:format)` → `base/app/secret_issuances#update`
- `PUT /secret_issuances/:id(.:format)` → `base/app/secret_issuances#update`
- `DELETE /secret_issuances/:id(.:format)` → `base/app/secret_issuances#destroy`
- `POST /groups/:group_id/avatar_memberships(.:format)` → `base/app/group_avatar_memberships#create` [base_app_group_avatar_memberships]
- `PATCH /groups/:group_id/avatar_memberships/:id(.:format)` → `base/app/group_avatar_memberships#update` [base_app_group_avatar_membership]
- `PUT /groups/:group_id/avatar_memberships/:id(.:format)` → `base/app/group_avatar_memberships#update`
- `DELETE /groups/:group_id/avatar_memberships/:id(.:format)` → `base/app/group_avatar_memberships#destroy`
- `GET /groups(.:format)` → `base/app/groups#index` [base_app_groups]
- `POST /groups(.:format)` → `base/app/groups#create`
- `GET /groups/:id(.:format)` → `base/app/groups#show` [base_app_group]
- `PATCH /groups/:id(.:format)` → `base/app/groups#update`
- `PUT /groups/:id(.:format)` → `base/app/groups#update`
- `DELETE /groups/:id(.:format)` → `base/app/groups#destroy`
- `GET /accounts(.:format)` → `base/app/accounts#index` [base_app_accounts]
- `GET /accounts/:id(.:format)` → `base/app/accounts#show` [base_app_account]
- `GET /organizations/:organization_id/memberships(.:format)` → `base/app/organizations/memberships#index` [base_app_organization_memberships]
- `POST /organizations/:organization_id/memberships(.:format)` → `base/app/organizations/memberships#create`
- `GET /organizations/:organization_id/memberships/new(.:format)` → `base/app/organizations/memberships#new` [new_base_app_organization_membership]
- `GET /organizations/:organization_id/memberships/:id/edit(.:format)` → `base/app/organizations/memberships#edit` [edit_base_app_organization_membership]
- `GET /organizations/:organization_id/memberships/:id(.:format)` → `base/app/organizations/memberships#show` [base_app_organization_membership]
- `PATCH /organizations/:organization_id/memberships/:id(.:format)` → `base/app/organizations/memberships#update`
- `PUT /organizations/:organization_id/memberships/:id(.:format)` → `base/app/organizations/memberships#update`
- `DELETE /organizations/:organization_id/memberships/:id(.:format)` → `base/app/organizations/memberships#destroy`
- `GET /organizations(.:format)` → `base/app/organizations#index` [base_app_organizations]
- `GET /organizations/:id(.:format)` → `base/app/organizations#show` [base_app_organization]
- `GET /preference(.:format)` → `base/app/preferences#show` [base_app_preference]
- `GET /preference/calendar/edit(.:format)` → `base/app/preference/calendars#edit` [edit_base_app_preference_calendar]
- `PATCH /preference/calendar(.:format)` → `base/app/preference/calendars#update` [base_app_preference_calendar]
- `PUT /preference/calendar(.:format)` → `base/app/preference/calendars#update`
- `GET /preference/clock/edit(.:format)` → `base/app/preference/clocks#edit` [edit_base_app_preference_clock]
- `PATCH /preference/clock(.:format)` → `base/app/preference/clocks#update` [base_app_preference_clock]
- `PUT /preference/clock(.:format)` → `base/app/preference/clocks#update`
- `GET /preference/cookie/edit(.:format)` → `base/app/preference/cookies#edit` [edit_base_app_preference_cookie]
- `PATCH /preference/cookie(.:format)` → `base/app/preference/cookies#update` [base_app_preference_cookie]
- `PUT /preference/cookie(.:format)` → `base/app/preference/cookies#update`
- `GET /preference/currency/edit(.:format)` → `base/app/preference/currencies#edit` [edit_base_app_preference_currency]
- `PATCH /preference/currency(.:format)` → `base/app/preference/currencies#update` [base_app_preference_currency]
- `PUT /preference/currency(.:format)` → `base/app/preference/currencies#update`
- `GET /preference/density/edit(.:format)` → `base/app/preference/densities#edit` [edit_base_app_preference_density]
- `PATCH /preference/density(.:format)` → `base/app/preference/densities#update` [base_app_preference_density]
- `PUT /preference/density(.:format)` → `base/app/preference/densities#update`
- `GET /preference/emails/:id/edit(.:format)` → `base/app/preference/emails#edit` [edit_base_app_preference_email]
- `DELETE /preference/emails/:id(.:format)` → `base/app/preference/emails#destroy` [base_app_preference_email]
- `POST /preference/emails/:id(.:format)` → `base/app/preference/emails#create`
- `GET /preference/language/edit(.:format)` → `base/app/preference/languages#edit` [edit_base_app_preference_language]
- `PATCH /preference/language(.:format)` → `base/app/preference/languages#update` [base_app_preference_language]
- `PUT /preference/language(.:format)` → `base/app/preference/languages#update`
- `GET /preference/motion/edit(.:format)` → `base/app/preference/motions#edit` [edit_base_app_preference_motion]
- `PATCH /preference/motion(.:format)` → `base/app/preference/motions#update` [base_app_preference_motion]
- `PUT /preference/motion(.:format)` → `base/app/preference/motions#update`
- `GET /preference/notification/edit(.:format)` → `base/app/preference/notifications#edit` [edit_base_app_preference_notification]
- `PATCH /preference/notification(.:format)` → `base/app/preference/notifications#update` [base_app_preference_notification]
- `PUT /preference/notification(.:format)` → `base/app/preference/notifications#update`
- `GET /preference/pagination/edit(.:format)` → `base/app/preference/paginations#edit` [edit_base_app_preference_pagination]
- `PATCH /preference/pagination(.:format)` → `base/app/preference/paginations#update` [base_app_preference_pagination]
- `PUT /preference/pagination(.:format)` → `base/app/preference/paginations#update`
- `GET /preference/region/edit(.:format)` → `base/app/preference/regions#edit` [edit_base_app_preference_region]
- `PATCH /preference/region(.:format)` → `base/app/preference/regions#update` [base_app_preference_region]
- `PUT /preference/region(.:format)` → `base/app/preference/regions#update`
- `GET /preference/customization/edit(.:format)` → `base/app/preference/customizations#edit` [edit_base_app_preference_customization]
- `DELETE /preference/customization(.:format)` → `base/app/preference/customizations#destroy` [base_app_preference_customization]
- `GET /preference/screen/edit(.:format)` → `base/app/preference/screens#edit` [edit_base_app_preference_screen]
- `PATCH /preference/screen(.:format)` → `base/app/preference/screens#update` [base_app_preference_screen]
- `PUT /preference/screen(.:format)` → `base/app/preference/screens#update`
- `GET /preference/theme/edit(.:format)` → `base/app/preference/themes#edit` [edit_base_app_preference_theme]
- `PATCH /preference/theme(.:format)` → `base/app/preference/themes#update` [base_app_preference_theme]
- `PUT /preference/theme(.:format)` → `base/app/preference/themes#update`
- `GET /preference/timezone/edit(.:format)` → `base/app/preference/timezones#edit` [edit_base_app_preference_timezone]
- `PATCH /preference/timezone(.:format)` → `base/app/preference/timezones#update` [base_app_preference_timezone]
- `PUT /preference/timezone(.:format)` → `base/app/preference/timezones#update`
- `GET /.well-known/jwks.json` → `base/app/well_known/jwks#show` [base_app_well_known_jwks]
- `GET /revision` → `base/app/revisions#show` [base_app_revision]
- `GET /health` → `base/app/healths#show` [base_app_health]
- `GET /health/liveness` → `base/app/health/livenesses#show` [base_app_health_liveness]
- `GET /health/readiness` → `base/app/health/readinesses#show` [base_app_health_readiness]
- `GET /health/startup` → `base/app/health/startups#show` [base_app_health_startup]
- `GET /api/v0/health.json` → `base/app/api/v0/healths#show` [base_app_api_v0_health]
- `GET /api/v0/revision.json` → `base/app/api/v0/revisions#show` [base_app_api_v0_revision]
- `GET /api/v0/identity/standing(.:format)` → `base/app/api/v0/identity/standings#show` [base_app_api_v0_identity_standing]
- `GET /api/v0/identity/selection(.:format)` → `base/app/api/v0/identity/selections#show` [base_app_api_v0_identity_selection]
- `GET /api/v0/membership/app/accounts(.:format)` → `base/app/api/v0/membership/directory#accounts` [base_app_api_v0_membership_accounts]
- `GET /api/v0/membership/app/accounts/:ref(.:format)` → `base/app/api/v0/membership/directory#account` [base_app_api_v0_membership_account]
- `GET /api/v0/membership/app/organizations(.:format)` → `base/app/api/v0/membership/directory#organizations` [base_app_api_v0_membership_organizations]
- `GET /api/v0/membership/app/organizations/:ref(.:format)` → `base/app/api/v0/membership/directory#organization` [base_app_api_v0_membership_organization]
- `GET /api/v0/membership/app/organizations/:organization_ref/memberships(.:format)` → `base/app/api/v0/membership/directory#memberships` [base_app_api_v0_membership_memberships]
- `GET /api/v0/membership/app/organizations/:organization_ref/memberships/:id(.:format)` → `base/app/api/v0/membership/directory#membership` [base_app_api_v0_membership_membership]
- `POST /api/v0/membership/app/organizations/:organization_ref/memberships/authorization(.:format)` → `base/app/api/v0/membership/directory#authorization` [base_app_api_v0_membership_membership_authorization]
- `GET /api/v0/avatar/app/switcher(.:format)` → `base/app/api/v0/avatar/switchers#show` [base_app_api_v0_avatar_switcher]
- `PUT /api/v0/avatar/app/switcher(.:format)` → `base/app/api/v0/avatar/switchers#update`
- `GET /api/v0/avatar/app/dashboard-identity(.:format)` → `base/app/api/v0/avatar/dashboard_identities#show` [base_app_api_v0_avatar_dashboard_identity]
- `GET /api/v0/avatar/app/selected-image(.:format)` → `base/app/api/v0/avatar/selected_images#show` [base_app_api_v0_avatar_selected_image]
- `GET /api/v0/avatar/app/avatars(.:format)` → `base/app/api/v0/avatar/avatars#index` [base_app_api_v0_avatar_avatars]
- `POST /api/v0/avatar/app/avatars(.:format)` → `base/app/api/v0/avatar/avatars#create`
- `GET /api/v0/avatar/app/avatars/:avatar_ref(.:format)` → `base/app/api/v0/avatar/avatars#show` [base_app_api_v0_avatar_avatar]
- `PATCH /api/v0/avatar/app/avatars/:avatar_ref(.:format)` → `base/app/api/v0/avatar/avatars#update`
- `PUT /api/v0/avatar/app/avatars/:avatar_ref(.:format)` → `base/app/api/v0/avatar/avatars#update`
- `POST /api/v0/avatar/app/avatars/:avatar_ref/:kind(.:format)` → `base/app/api/v0/avatar/social_edges#create` [base_app_api_v0_avatar_avatar_social_edge]
- `DELETE /api/v0/avatar/app/avatars/:avatar_ref/:kind(.:format)` → `base/app/api/v0/avatar/social_edges#destroy` [base_app_api_v0_avatar]
- `POST /api/v0/avatar/app/ownership-transfers(.:format)` → `base/app/api/v0/avatar/avatar_ownership_transfers#create` [base_app_api_v0_avatar_ownership_transfers]
- `POST /api/v0/avatar/app/ownership-transfers/:ref/accept(.:format)` → `base/app/api/v0/avatar/avatar_ownership_transfers#accept` [base_app_api_v0_avatar_accept_ownership_transfer]
- `POST /api/v0/avatar/app/ownership-transfers/:ref/cancel(.:format)` → `base/app/api/v0/avatar/avatar_ownership_transfers#cancel` [base_app_api_v0_avatar_cancel_ownership_transfer]
- `POST /api/v0/avatar/app/groups/:group_ref/avatar-memberships(.:format)` → `base/app/api/v0/avatar/group_avatar_memberships#create` [base_app_api_v0_avatar_group_avatar_memberships]
- `PATCH /api/v0/avatar/app/groups/:group_ref/avatar-memberships/:ref(.:format)` → `base/app/api/v0/avatar/group_avatar_memberships#update` [base_app_api_v0_avatar_group_avatar_membership]
- `PUT /api/v0/avatar/app/groups/:group_ref/avatar-memberships/:ref(.:format)` → `base/app/api/v0/avatar/group_avatar_memberships#update`
- `DELETE /api/v0/avatar/app/groups/:group_ref/avatar-memberships/:ref(.:format)` → `base/app/api/v0/avatar/group_avatar_memberships#destroy`
- `GET /api/v0/avatar/app/groups(.:format)` → `base/app/api/v0/avatar/groups#index` [base_app_api_v0_avatar_groups]
- `POST /api/v0/avatar/app/groups(.:format)` → `base/app/api/v0/avatar/groups#create`
- `GET /api/v0/avatar/app/groups/:ref(.:format)` → `base/app/api/v0/avatar/groups#show` [base_app_api_v0_avatar_group]
- `PATCH /api/v0/avatar/app/groups/:ref(.:format)` → `base/app/api/v0/avatar/groups#update`
- `PUT /api/v0/avatar/app/groups/:ref(.:format)` → `base/app/api/v0/avatar/groups#update`
- `DELETE /api/v0/avatar/app/groups/:ref(.:format)` → `base/app/api/v0/avatar/groups#destroy`
- `GET /robots.txt(.:format)` → `base/app/robots#index` [base_app_robots]
- `GET /sitemap.xml(.:format)` → `base/app/sitemaps#show` [base_app_sitemap]
- `POST /csp-violation-report(.:format)` → `base/app/csp_violation_reports#create` [base_app_csp_violation_report]
- `GET /service-worker(.:format)` → `rails/pwa#service_worker` [base_app_pwa_service_worker]
- `GET /offline(.:format)` → `rails/pwa#offline` [base_app_pwa_offline]
- `GET /api/v0/preferences/cookie(.:format)` → `base/app/api/v0/preferences/cookies#show` [base_app_api_v0_preferences_cookie]
- `PATCH /api/v0/preferences/cookie(.:format)` → `base/app/api/v0/preferences/cookies#update`
- `GET /api/v0/preferences/theme(.:format)` → `base/app/api/v0/preferences/themes#show` [base_app_api_v0_preferences_theme]
- `PATCH /api/v0/preferences/theme(.:format)` → `base/app/api/v0/preferences/themes#update`
- `GET /api/v0/preferences/web_push(.:format)` → `base/app/api/v0/preferences/web_pushes#show` [base_app_api_v0_preferences_web_push]
- `PATCH /api/v0/preferences/web_push(.:format)` → `base/app/api/v0/preferences/web_pushes#update`
- `GET /verification(.:format)` → `base/app/verifications#show` [base_app_verification]
- `POST /verification(.:format)` → `base/app/verifications#create`
- `GET /verification/cancellation(.:format)` → `base/app/verification/cancellations#show` [base_app_verification_cancellation]
- `POST /verification/cancellation(.:format)` → `base/app/verification/cancellations#create`
- `GET /verification/completion(.:format)` → `base/app/verification/completions#show` [base_app_verification_completion]
- `POST /verification/completion(.:format)` → `base/app/verification/completions#create`
- `GET /verification/setup(.:format)` → `base/app/verification/setups#show` [base_app_verification_setup]
- `POST /verification/setup(.:format)` → `base/app/verification/setups#create`
- `GET /identity(.:format)` → `base/app/identities#show` [base_app_identity]
- `GET /sessions(.:format)` → `base/app/identity/sessions#index` [base_app_sessions]
- `GET /sessions/:id(.:format)` → `base/app/identity/sessions#show` [base_app_session]
- `GET /identity/standing(.:format)` → `base/app/identity/standings#show` [base_app_identity_standing]
- `GET /identity/passkeys(.:format)` → `base/app/identity/passkeys#index` [base_app_identity_passkeys]
- `GET /identity/passkeys/:id(.:format)` → `base/app/identity/passkeys#show` [base_app_identity_passkey]
- `GET /identity/totps(.:format)` → `base/app/identity/totps#index` [base_app_identity_totps]
- `GET /identity/totps/:id(.:format)` → `base/app/identity/totps#show` [base_app_identity_totp]
- `GET /identity/emails(.:format)` → `base/app/identity/emails#index` [base_app_identity_emails]
- `GET /identity/telephones(.:format)` → `base/app/identity/telephones#index` [base_app_identity_telephones]
- `GET /identity/birthdate(.:format)` → `base/app/identity/birthdates#show` [base_app_identity_birthdate]
- `GET /identity/sessions(.:format)` → `base/app/identity/sessions#index` [base_app_identity_sessions]
- `GET /identity/sessions/:id(.:format)` → `base/app/identity/sessions#show` [base_app_identity_session]
- `GET /identity/activities(.:format)` → `base/app/identity/activities#index` [base_app_identity_activities]
- `GET /identity/withdrawal/new(.:format)` → `base/app/identity/withdrawals#new` [new_base_app_identity_withdrawal]
- `GET /identity/withdrawal/edit(.:format)` → `base/app/identity/withdrawals#edit` [edit_base_app_identity_withdrawal]
- `PATCH /identity/withdrawal(.:format)` → `base/app/identity/withdrawals#update` [base_app_identity_withdrawal]
- `PUT /identity/withdrawal(.:format)` → `base/app/identity/withdrawals#update`
- `DELETE /identity/withdrawal(.:format)` → `base/app/identity/withdrawals#destroy`
- `POST /identity/withdrawal(.:format)` → `base/app/identity/withdrawals#create`
- `GET /identity/withdrawal/session/new(.:format)` → `base/app/identity/withdrawal/sessions#new` [new_base_app_identity_withdrawal_session]
- `DELETE /identity/withdrawal/session(.:format)` → `base/app/identity/withdrawal/sessions#destroy` [base_app_identity_withdrawal_session]
- `POST /identity/withdrawal/session(.:format)` → `base/app/identity/withdrawal/sessions#create`
- `GET /identity/privacy/erasure/new(.:format)` → `base/app/identity/privacy/erasures#new` [new_base_app_identity_privacy_erasure]
- `POST /identity/privacy/erasure(.:format)` → `base/app/identity/privacy/erasures#create` [base_app_identity_privacy_erasure]
- `GET /identity/privacy/erasure/status(.:format)` → `base/app/identity/privacy/erasure/statuses#show` [base_app_identity_privacy_erasure_status]

### base_com — 61 route objects

- `GET /` → `base/com/roots#index` [base_com_root]
- `GET /preference(.:format)` → `base/com/preferences#show` [base_com_preference]
- `GET /preference/calendar/edit(.:format)` → `base/com/preference/calendars#edit` [edit_base_com_preference_calendar]
- `PATCH /preference/calendar(.:format)` → `base/com/preference/calendars#update` [base_com_preference_calendar]
- `PUT /preference/calendar(.:format)` → `base/com/preference/calendars#update`
- `GET /preference/clock/edit(.:format)` → `base/com/preference/clocks#edit` [edit_base_com_preference_clock]
- `PATCH /preference/clock(.:format)` → `base/com/preference/clocks#update` [base_com_preference_clock]
- `PUT /preference/clock(.:format)` → `base/com/preference/clocks#update`
- `GET /preference/cookie/edit(.:format)` → `base/com/preference/cookies#edit` [edit_base_com_preference_cookie]
- `PATCH /preference/cookie(.:format)` → `base/com/preference/cookies#update` [base_com_preference_cookie]
- `PUT /preference/cookie(.:format)` → `base/com/preference/cookies#update`
- `GET /preference/currency/edit(.:format)` → `base/com/preference/currencies#edit` [edit_base_com_preference_currency]
- `PATCH /preference/currency(.:format)` → `base/com/preference/currencies#update` [base_com_preference_currency]
- `PUT /preference/currency(.:format)` → `base/com/preference/currencies#update`
- `GET /preference/density/edit(.:format)` → `base/com/preference/densities#edit` [edit_base_com_preference_density]
- `PATCH /preference/density(.:format)` → `base/com/preference/densities#update` [base_com_preference_density]
- `PUT /preference/density(.:format)` → `base/com/preference/densities#update`
- `GET /preference/language/edit(.:format)` → `base/com/preference/languages#edit` [edit_base_com_preference_language]
- `PATCH /preference/language(.:format)` → `base/com/preference/languages#update` [base_com_preference_language]
- `PUT /preference/language(.:format)` → `base/com/preference/languages#update`
- `GET /preference/motion/edit(.:format)` → `base/com/preference/motions#edit` [edit_base_com_preference_motion]
- `PATCH /preference/motion(.:format)` → `base/com/preference/motions#update` [base_com_preference_motion]
- `PUT /preference/motion(.:format)` → `base/com/preference/motions#update`
- `GET /preference/notification/edit(.:format)` → `base/com/preference/notifications#edit` [edit_base_com_preference_notification]
- `PATCH /preference/notification(.:format)` → `base/com/preference/notifications#update` [base_com_preference_notification]
- `PUT /preference/notification(.:format)` → `base/com/preference/notifications#update`
- `GET /preference/pagination/edit(.:format)` → `base/com/preference/paginations#edit` [edit_base_com_preference_pagination]
- `PATCH /preference/pagination(.:format)` → `base/com/preference/paginations#update` [base_com_preference_pagination]
- `PUT /preference/pagination(.:format)` → `base/com/preference/paginations#update`
- `GET /preference/region/edit(.:format)` → `base/com/preference/regions#edit` [edit_base_com_preference_region]
- `PATCH /preference/region(.:format)` → `base/com/preference/regions#update` [base_com_preference_region]
- `PUT /preference/region(.:format)` → `base/com/preference/regions#update`
- `GET /preference/customization/edit(.:format)` → `base/com/preference/customizations#edit` [edit_base_com_preference_customization]
- `DELETE /preference/customization(.:format)` → `base/com/preference/customizations#destroy` [base_com_preference_customization]
- `GET /preference/screen/edit(.:format)` → `base/com/preference/screens#edit` [edit_base_com_preference_screen]
- `PATCH /preference/screen(.:format)` → `base/com/preference/screens#update` [base_com_preference_screen]
- `PUT /preference/screen(.:format)` → `base/com/preference/screens#update`
- `GET /preference/theme/edit(.:format)` → `base/com/preference/themes#edit` [edit_base_com_preference_theme]
- `PATCH /preference/theme(.:format)` → `base/com/preference/themes#update` [base_com_preference_theme]
- `PUT /preference/theme(.:format)` → `base/com/preference/themes#update`
- `GET /preference/timezone/edit(.:format)` → `base/com/preference/timezones#edit` [edit_base_com_preference_timezone]
- `PATCH /preference/timezone(.:format)` → `base/com/preference/timezones#update` [base_com_preference_timezone]
- `PUT /preference/timezone(.:format)` → `base/com/preference/timezones#update`
- `GET /revision` → `base/com/revisions#show` [base_com_revision]
- `GET /health` → `base/com/healths#show` [base_com_health]
- `GET /health/liveness` → `base/com/health/livenesses#show` [base_com_health_liveness]
- `GET /health/readiness` → `base/com/health/readinesses#show` [base_com_health_readiness]
- `GET /health/startup` → `base/com/health/startups#show` [base_com_health_startup]
- `GET /api/v0/health.json` → `base/com/api/v0/healths#show` [base_com_api_v0_health]
- `GET /api/v0/revision.json` → `base/com/api/v0/revisions#show` [base_com_api_v0_revision]
- `GET /api/v0/preferences/cookie(.:format)` → `base/com/api/v0/preferences/cookies#show` [base_com_api_v0_preferences_cookie]
- `PATCH /api/v0/preferences/cookie(.:format)` → `base/com/api/v0/preferences/cookies#update`
- `GET /api/v0/preferences/theme(.:format)` → `base/com/api/v0/preferences/themes#show` [base_com_api_v0_preferences_theme]
- `PATCH /api/v0/preferences/theme(.:format)` → `base/com/api/v0/preferences/themes#update`
- `GET /api/v0/preferences/web_push(.:format)` → `base/com/api/v0/preferences/web_pushes#show` [base_com_api_v0_preferences_web_push]
- `PATCH /api/v0/preferences/web_push(.:format)` → `base/com/api/v0/preferences/web_pushes#update`
- `GET /robots.txt(.:format)` → `base/com/robots#index` [base_com_robots]
- `GET /sitemap.xml(.:format)` → `base/com/sitemaps#show` [base_com_sitemap]
- `POST /csp-violation-report(.:format)` → `base/com/csp_violation_reports#create` [base_com_csp_violation_report]
- `GET /service-worker(.:format)` → `rails/pwa#service_worker` [base_com_pwa_service_worker]
- `GET /offline(.:format)` → `rails/pwa#offline` [base_com_pwa_offline]

### base_staff — 189 route objects

- `GET /` → `base/org/roots#index` [base_org_root]
- `GET /welcome(.:format)` → `base/org/welcomes#show` [base_org_welcome]
- `GET /dashboard/avatar_image(.:format)` → `base/org/dashboard_avatar_images#show` [base_org_dashboard_avatar_image]
- `GET /dashboard(.:format)` → `base/org/roots#show` [base_org_dashboard]
- `GET /selector(.:format)` → `base/org/selectors#show` [base_org_selector]
- `PATCH /selector(.:format)` → `base/org/selectors#update`
- `PUT /selector(.:format)` → `base/org/selectors#update`
- `GET /switcher(.:format)` → `base/org/switchers#show` [base_org_switcher]
- `PATCH /switcher(.:format)` → `base/org/switchers#update`
- `PUT /switcher(.:format)` → `base/org/switchers#update`
- `GET /preference(.:format)` → `base/org/preferences#show` [base_org_preference]
- `GET /organizations/:organization_id/memberships(.:format)` → `base/org/organizations/memberships#index` [base_org_organization_memberships]
- `GET /organizations/:organization_id/memberships/:id(.:format)` → `base/org/organizations/memberships#show` [base_org_organization_membership]
- `GET /organizations(.:format)` → `base/org/organizations#index` [base_org_organizations]
- `GET /organizations/:id(.:format)` → `base/org/organizations#show` [base_org_organization]
- `GET /preference/calendar/edit(.:format)` → `base/org/preference/calendars#edit` [edit_base_org_preference_calendar]
- `PATCH /preference/calendar(.:format)` → `base/org/preference/calendars#update` [base_org_preference_calendar]
- `PUT /preference/calendar(.:format)` → `base/org/preference/calendars#update`
- `GET /preference/clock/edit(.:format)` → `base/org/preference/clocks#edit` [edit_base_org_preference_clock]
- `PATCH /preference/clock(.:format)` → `base/org/preference/clocks#update` [base_org_preference_clock]
- `PUT /preference/clock(.:format)` → `base/org/preference/clocks#update`
- `GET /preference/cookie/edit(.:format)` → `base/org/preference/cookies#edit` [edit_base_org_preference_cookie]
- `PATCH /preference/cookie(.:format)` → `base/org/preference/cookies#update` [base_org_preference_cookie]
- `PUT /preference/cookie(.:format)` → `base/org/preference/cookies#update`
- `GET /preference/currency/edit(.:format)` → `base/org/preference/currencies#edit` [edit_base_org_preference_currency]
- `PATCH /preference/currency(.:format)` → `base/org/preference/currencies#update` [base_org_preference_currency]
- `PUT /preference/currency(.:format)` → `base/org/preference/currencies#update`
- `GET /preference/density/edit(.:format)` → `base/org/preference/densities#edit` [edit_base_org_preference_density]
- `PATCH /preference/density(.:format)` → `base/org/preference/densities#update` [base_org_preference_density]
- `PUT /preference/density(.:format)` → `base/org/preference/densities#update`
- `GET /preference/emails/:id/edit(.:format)` → `base/org/preference/emails#edit` [edit_base_org_preference_email]
- `DELETE /preference/emails/:id(.:format)` → `base/org/preference/emails#destroy` [base_org_preference_email]
- `POST /preference/emails/:id(.:format)` → `base/org/preference/emails#create`
- `GET /preference/language/edit(.:format)` → `base/org/preference/languages#edit` [edit_base_org_preference_language]
- `PATCH /preference/language(.:format)` → `base/org/preference/languages#update` [base_org_preference_language]
- `PUT /preference/language(.:format)` → `base/org/preference/languages#update`
- `GET /preference/motion/edit(.:format)` → `base/org/preference/motions#edit` [edit_base_org_preference_motion]
- `PATCH /preference/motion(.:format)` → `base/org/preference/motions#update` [base_org_preference_motion]
- `PUT /preference/motion(.:format)` → `base/org/preference/motions#update`
- `GET /preference/notification/edit(.:format)` → `base/org/preference/notifications#edit` [edit_base_org_preference_notification]
- `PATCH /preference/notification(.:format)` → `base/org/preference/notifications#update` [base_org_preference_notification]
- `PUT /preference/notification(.:format)` → `base/org/preference/notifications#update`
- `GET /preference/pagination/edit(.:format)` → `base/org/preference/paginations#edit` [edit_base_org_preference_pagination]
- `PATCH /preference/pagination(.:format)` → `base/org/preference/paginations#update` [base_org_preference_pagination]
- `PUT /preference/pagination(.:format)` → `base/org/preference/paginations#update`
- `GET /preference/region/edit(.:format)` → `base/org/preference/regions#edit` [edit_base_org_preference_region]
- `PATCH /preference/region(.:format)` → `base/org/preference/regions#update` [base_org_preference_region]
- `PUT /preference/region(.:format)` → `base/org/preference/regions#update`
- `GET /preference/customization/edit(.:format)` → `base/org/preference/customizations#edit` [edit_base_org_preference_customization]
- `DELETE /preference/customization(.:format)` → `base/org/preference/customizations#destroy` [base_org_preference_customization]
- `GET /preference/screen/edit(.:format)` → `base/org/preference/screens#edit` [edit_base_org_preference_screen]
- `PATCH /preference/screen(.:format)` → `base/org/preference/screens#update` [base_org_preference_screen]
- `PUT /preference/screen(.:format)` → `base/org/preference/screens#update`
- `GET /preference/theme/edit(.:format)` → `base/org/preference/themes#edit` [edit_base_org_preference_theme]
- `PATCH /preference/theme(.:format)` → `base/org/preference/themes#update` [base_org_preference_theme]
- `PUT /preference/theme(.:format)` → `base/org/preference/themes#update`
- `GET /preference/timezone/edit(.:format)` → `base/org/preference/timezones#edit` [edit_base_org_preference_timezone]
- `PATCH /preference/timezone(.:format)` → `base/org/preference/timezones#update` [base_org_preference_timezone]
- `PUT /preference/timezone(.:format)` → `base/org/preference/timezones#update`
- `GET /.well-known/jwks.json` → `base/org/well_known/jwks#show` [base_org_well_known_jwks]
- `GET /revision` → `base/org/revisions#show` [base_org_revision]
- `GET /health` → `base/org/healths#show` [base_org_health]
- `GET /health/liveness` → `base/org/health/livenesses#show` [base_org_health_liveness]
- `GET /health/readiness` → `base/org/health/readinesses#show` [base_org_health_readiness]
- `GET /health/startup` → `base/org/health/startups#show` [base_org_health_startup]
- `GET /api/v0/health.json` → `base/org/api/v0/healths#show` [base_org_api_v0_health]
- `GET /api/v0/revision.json` → `base/org/api/v0/revisions#show` [base_org_api_v0_revision]
- `GET /api/v0/identity/standing(.:format)` → `base/org/api/v0/identity/standings#show` [base_org_api_v0_identity_standing]
- `GET /api/v0/identity/selection(.:format)` → `base/org/api/v0/identity/selections#show` [base_org_api_v0_identity_selection]
- `GET /api/v0/membership/org/accounts(.:format)` → `base/org/api/v0/membership/directory#accounts` [base_org_api_v0_membership_accounts]
- `GET /api/v0/membership/org/accounts/:ref(.:format)` → `base/org/api/v0/membership/directory#account` [base_org_api_v0_membership_account]
- `GET /api/v0/membership/org/organizations(.:format)` → `base/org/api/v0/membership/directory#organizations` [base_org_api_v0_membership_organizations]
- `GET /api/v0/membership/org/organizations/:ref(.:format)` → `base/org/api/v0/membership/directory#organization` [base_org_api_v0_membership_organization]
- `GET /api/v0/membership/org/organizations/:organization_ref/memberships(.:format)` → `base/org/api/v0/membership/directory#memberships` [base_org_api_v0_membership_memberships]
- `GET /api/v0/membership/org/organizations/:organization_ref/memberships/:id(.:format)` → `base/org/api/v0/membership/directory#membership` [base_org_api_v0_membership_membership]
- `POST /api/v0/membership/org/organizations/:organization_ref/memberships/authorization(.:format)` → `base/org/api/v0/membership/directory#authorization` [base_org_api_v0_membership_membership_authorization]
- `GET /api/v0/support(.:format)` → `base/org/api/v0/support/areas#index` [base_org_api_v0_support_areas]
- `GET /api/v0/support/:realm/accounts(.:format)` → `base/org/api/v0/support/accounts#index` [base_org_api_v0_support_accounts]
- `GET /api/v0/support/:realm/accounts/:ref(.:format)` → `base/org/api/v0/support/accounts#show` [base_org_api_v0_support_account]
- `GET /api/v0/support/:realm/accounts/:ref/revocation-screen(.:format)` → `base/org/api/v0/support/accounts#revocation_screen` [base_org_api_v0_support_revocation_screen]
- `POST /api/v0/support/:realm/accounts/:ref/revocations(.:format)` → `base/org/api/v0/support/accounts#revoke` [base_org_api_v0_support_revocations]
- `GET /api/v0/support/:realm/accounts/:ref/revocations/:event_uuid(.:format)` → `base/org/api/v0/support/accounts#revocation` [base_org_api_v0_support_revocation]
- `GET /api/v0/support/:realm/enforcement_cases/:enforcement_case_id/approval/new(.:format)` → `base/org/api/v0/support/enforcement_cases/approvals#new` [new_base_org_api_v0_support_enforcement_enforcement_case_approval]
- `POST /api/v0/support/:realm/enforcement_cases/:enforcement_case_id/approval(.:format)` → `base/org/api/v0/support/enforcement_cases/approvals#create` [base_org_api_v0_support_enforcement_enforcement_case_approval]
- `GET /api/v0/support/:realm/enforcement_cases/:enforcement_case_id/release/new(.:format)` → `base/org/api/v0/support/enforcement_cases/releases#new` [new_base_org_api_v0_support_enforcement_enforcement_case_release]
- `POST /api/v0/support/:realm/enforcement_cases/:enforcement_case_id/release(.:format)` → `base/org/api/v0/support/enforcement_cases/releases#create` [base_org_api_v0_support_enforcement_enforcement_case_release]
- `GET /api/v0/support/:realm/enforcement_cases/:enforcement_case_id/appeal_review/new(.:format)` → `base/org/api/v0/support/enforcement_cases/appeal_reviews#new` [new_base_org_api_v0_support_enforcement_enforcement_case_appeal_review]
- `POST /api/v0/support/:realm/enforcement_cases/:enforcement_case_id/appeal_review(.:format)` → `base/org/api/v0/support/enforcement_cases/appeal_reviews#create` [base_org_api_v0_support_enforcement_enforcement_case_appeal_review]
- `GET /api/v0/support/:realm/enforcement_cases(.:format)` → `base/org/api/v0/support/enforcement_cases#index` [base_org_api_v0_support_enforcement_enforcement_cases]
- `POST /api/v0/support/:realm/enforcement_cases(.:format)` → `base/org/api/v0/support/enforcement_cases#create`
- `GET /api/v0/support/:realm/enforcement_cases/new(.:format)` → `base/org/api/v0/support/enforcement_cases#new` [new_base_org_api_v0_support_enforcement_enforcement_case]
- `GET /api/v0/support/:realm/enforcement_cases/:id(.:format)` → `base/org/api/v0/support/enforcement_cases#show` [base_org_api_v0_support_enforcement_enforcement_case]
- `GET /api/v0/iam/grants(.:format)` → `base/org/api/v0/iam/grants#index` [base_org_api_v0_iam_grants]
- `GET /api/v0/iam/grant-screen(.:format)` → `base/org/api/v0/iam/grants#screen` [base_org_api_v0_iam_grant_screen]
- `POST /api/v0/iam/grants(.:format)` → `base/org/api/v0/iam/grants#create`
- `GET /api/v0/iam/grants/:ref(.:format)` → `base/org/api/v0/iam/grants#show` [base_org_api_v0_iam_grant]
- `POST /api/v0/iam/grants/:ref/revocation(.:format)` → `base/org/api/v0/iam/grants#revoke` [base_org_api_v0_iam_grant_revocation]
- `GET /api/v0/avatar/org/dashboard-identity(.:format)` → `base/org/api/v0/avatar/dashboard_identities#show` [base_org_api_v0_avatar_dashboard_identity]
- `GET /api/v0/avatar/org/switcher(.:format)` → `base/org/api/v0/avatar/switchers#show` [base_org_api_v0_avatar_switcher]
- `PUT /api/v0/avatar/org/switcher(.:format)` → `base/org/api/v0/avatar/switchers#update`
- `GET /api/v0/avatar/org/selected-avatar(.:format)` → `base/org/api/v0/avatar/selected_avatars#show` [base_org_api_v0_avatar_selected_avatar]
- `PATCH /api/v0/avatar/org/selected-avatar(.:format)` → `base/org/api/v0/avatar/selected_avatars#update`
- `DELETE /api/v0/avatar/org/selected-avatar(.:format)` → `base/org/api/v0/avatar/selected_avatars#destroy`
- `GET /api/v0/avatar/org/selected-image(.:format)` → `base/org/api/v0/avatar/selected_images#show` [base_org_api_v0_avatar_selected_image]
- `POST /api/v0/avatar/org/ownership-transfers(.:format)` → `base/org/api/v0/avatar/avatar_ownership_transfers#create` [base_org_api_v0_avatar_ownership_transfers]
- `POST /api/v0/avatar/org/ownership-transfers/:ref/accept(.:format)` → `base/org/api/v0/avatar/avatar_ownership_transfers#accept` [base_org_api_v0_avatar_accept_ownership_transfer]
- `POST /api/v0/avatar/org/ownership-transfers/:ref/cancel(.:format)` → `base/org/api/v0/avatar/avatar_ownership_transfers#cancel` [base_org_api_v0_avatar_cancel_ownership_transfer]
- `POST /api/v0/tech-capability-checks(.:format)` → `base/org/api/v0/tech_capability_checks#create` [base_org_api_v0_tech_capability_check]
- `GET /robots.txt(.:format)` → `base/org/robots#index` [base_org_robots]
- `GET /sitemap.xml(.:format)` → `base/org/sitemaps#show` [base_org_sitemap]
- `POST /csp-violation-report(.:format)` → `base/org/csp_violation_reports#create` [base_org_csp_violation_report]
- `GET /service-worker(.:format)` → `rails/pwa#service_worker` [base_org_pwa_service_worker]
- `GET /offline(.:format)` → `rails/pwa#offline` [base_org_pwa_offline]
- `GET /settings(.:format)` → `base/org/settings#show` [base_org_settings]
- `GET /accounts(.:format)` → `base/org/accounts#index` [base_org_accounts]
- `GET /accounts/:id(.:format)` → `base/org/accounts#show` [base_org_account]
- `GET /iam(.:format)` → `base/org/iam#index` [base_org_iam_index]
- `GET /iam/grants/:grant_id/revocation/new(.:format)` → `base/org/iam/grants/revocations#new` [new_base_org_iam_grant_revocation]
- `POST /iam/grants/:grant_id/revocation(.:format)` → `base/org/iam/grants/revocations#create` [base_org_iam_grant_revocation]
- `GET /iam/grants(.:format)` → `base/org/iam/grants#index` [base_org_iam_grants]
- `POST /iam/grants(.:format)` → `base/org/iam/grants#create`
- `GET /iam/grants/new(.:format)` → `base/org/iam/grants#new` [new_base_org_iam_grant]
- `GET /iam/grants/:id(.:format)` → `base/org/iam/grants#show` [base_org_iam_grant]
- `GET /system(.:format)` → `base/org/system#index` [base_org_system_index]
- `GET /audit(.:format)` → `base/org/audit#index` [base_org_audit_index]
- `GET /support(.:format)` → `base/org/support#index` [base_org_support_index]
- `POST /support/clients/:client_id/revocations(.:format)` → `base/org/support/clients/revocations#create` [base_org_support_client_revocations]
- `GET /support/clients/:client_id/revocations/new(.:format)` → `base/org/support/clients/revocations#new` [new_base_org_support_client_revocation]
- `GET /support/clients/:client_id/revocations/:id(.:format)` → `base/org/support/clients/revocations#show` [base_org_support_client_revocation]
- `GET /support/clients(.:format)` → `base/org/support/clients#index` [base_org_support_clients]
- `GET /support/clients/:id(.:format)` → `base/org/support/clients#show` [base_org_support_client]
- `GET /support/app/enforcement_cases/:enforcement_case_id/approval/new(.:format)` → `base/org/support/enforcement_cases/approvals#new` [new_base_org_support_app_enforcement_case_approval]
- `POST /support/app/enforcement_cases/:enforcement_case_id/approval(.:format)` → `base/org/support/enforcement_cases/approvals#create` [base_org_support_app_enforcement_case_approval]
- `GET /support/app/enforcement_cases/:enforcement_case_id/release/new(.:format)` → `base/org/support/enforcement_cases/releases#new` [new_base_org_support_app_enforcement_case_release]
- `POST /support/app/enforcement_cases/:enforcement_case_id/release(.:format)` → `base/org/support/enforcement_cases/releases#create` [base_org_support_app_enforcement_case_release]
- `GET /support/app/enforcement_cases/:enforcement_case_id/appeal_review/new(.:format)` → `base/org/support/enforcement_cases/appeal_reviews#new` [new_base_org_support_app_enforcement_case_appeal_review]
- `POST /support/app/enforcement_cases/:enforcement_case_id/appeal_review(.:format)` → `base/org/support/enforcement_cases/appeal_reviews#create` [base_org_support_app_enforcement_case_appeal_review]
- `GET /support/app/enforcement_cases(.:format)` → `base/org/support/enforcement_cases#index` [base_org_support_app_enforcement_cases]
- `POST /support/app/enforcement_cases(.:format)` → `base/org/support/enforcement_cases#create`
- `GET /support/app/enforcement_cases/new(.:format)` → `base/org/support/enforcement_cases#new` [new_base_org_support_app_enforcement_case]
- `GET /support/app/enforcement_cases/:id(.:format)` → `base/org/support/enforcement_cases#show` [base_org_support_app_enforcement_case]
- `GET /support/org/enforcement_cases/:enforcement_case_id/approval/new(.:format)` → `base/org/support/enforcement_cases/approvals#new` [new_base_org_support_org_enforcement_case_approval]
- `POST /support/org/enforcement_cases/:enforcement_case_id/approval(.:format)` → `base/org/support/enforcement_cases/approvals#create` [base_org_support_org_enforcement_case_approval]
- `GET /support/org/enforcement_cases/:enforcement_case_id/release/new(.:format)` → `base/org/support/enforcement_cases/releases#new` [new_base_org_support_org_enforcement_case_release]
- `POST /support/org/enforcement_cases/:enforcement_case_id/release(.:format)` → `base/org/support/enforcement_cases/releases#create` [base_org_support_org_enforcement_case_release]
- `GET /support/org/enforcement_cases/:enforcement_case_id/appeal_review/new(.:format)` → `base/org/support/enforcement_cases/appeal_reviews#new` [new_base_org_support_org_enforcement_case_appeal_review]
- `POST /support/org/enforcement_cases/:enforcement_case_id/appeal_review(.:format)` → `base/org/support/enforcement_cases/appeal_reviews#create` [base_org_support_org_enforcement_case_appeal_review]
- `GET /support/org/enforcement_cases(.:format)` → `base/org/support/enforcement_cases#index` [base_org_support_org_enforcement_cases]
- `POST /support/org/enforcement_cases(.:format)` → `base/org/support/enforcement_cases#create`
- `GET /support/org/enforcement_cases/new(.:format)` → `base/org/support/enforcement_cases#new` [new_base_org_support_org_enforcement_case]
- `GET /support/org/enforcement_cases/:id(.:format)` → `base/org/support/enforcement_cases#show` [base_org_support_org_enforcement_case]
- `GET /billing(.:format)` → `base/org/billing#index` [base_org_billing_index]
- `GET /api/v0/preferences/cookie(.:format)` → `base/org/api/v0/preferences/cookies#show` [base_org_api_v0_preferences_cookie]
- `PATCH /api/v0/preferences/cookie(.:format)` → `base/org/api/v0/preferences/cookies#update`
- `GET /api/v0/preferences/theme(.:format)` → `base/org/api/v0/preferences/themes#show` [base_org_api_v0_preferences_theme]
- `PATCH /api/v0/preferences/theme(.:format)` → `base/org/api/v0/preferences/themes#update`
- `GET /api/v0/preferences/web_push(.:format)` → `base/org/api/v0/preferences/web_pushes#show` [base_org_api_v0_preferences_web_push]
- `PATCH /api/v0/preferences/web_push(.:format)` → `base/org/api/v0/preferences/web_pushes#update`
- `GET /verification(.:format)` → `base/org/verifications#show` [base_org_verification]
- `POST /verification(.:format)` → `base/org/verifications#create`
- `GET /verification/cancellation(.:format)` → `base/org/verification/cancellations#show` [base_org_verification_cancellation]
- `POST /verification/cancellation(.:format)` → `base/org/verification/cancellations#create`
- `GET /verification/completion(.:format)` → `base/org/verification/completions#show` [base_org_verification_completion]
- `POST /verification/completion(.:format)` → `base/org/verification/completions#create`
- `GET /verification/setup(.:format)` → `base/org/verification/setups#show` [base_org_verification_setup]
- `POST /verification/setup(.:format)` → `base/org/verification/setups#create`
- `GET /identity(.:format)` → `base/org/identities#show` [base_org_identity]
- `GET /sessions(.:format)` → `base/org/identity/sessions#index` [base_org_sessions]
- `GET /sessions/:id(.:format)` → `base/org/identity/sessions#show` [base_org_session]
- `GET /identity/standing(.:format)` → `base/org/identity/standings#show` [base_org_identity_standing]
- `GET /identity/passkeys(.:format)` → `base/org/identity/passkeys#index` [base_org_identity_passkeys]
- `GET /identity/passkeys/:id(.:format)` → `base/org/identity/passkeys#show` [base_org_identity_passkey]
- `GET /identity/emails(.:format)` → `base/org/identity/emails#index` [base_org_identity_emails]
- `GET /identity/telephones(.:format)` → `base/org/identity/telephones#index` [base_org_identity_telephones]
- `GET /identity/birthdate(.:format)` → `base/org/identity/birthdates#show` [base_org_identity_birthdate]
- `POST /identity/secrets/:secret_id/rotation(.:format)` → `base/org/identity/rotations#create` [base_org_identity_secret_rotation]
- `POST /identity/secrets/:secret_id/removal(.:format)` → `base/org/identity/removals#create` [base_org_identity_secret_removal]
- `GET /identity/secrets(.:format)` → `base/org/identity/secret_credentials#index` [base_org_identity_secrets]
- `POST /identity/secrets(.:format)` → `base/org/identity/secret_credentials#create`
- `GET /identity/secrets/new(.:format)` → `base/org/identity/secret_credentials#new` [new_base_org_identity_secret]
- `GET /identity/secrets/:id/edit(.:format)` → `base/org/identity/secret_credentials#edit` [edit_base_org_identity_secret]
- `GET /identity/secrets/:id(.:format)` → `base/org/identity/secret_credentials#show` [base_org_identity_secret]
- `PATCH /identity/secrets/:id(.:format)` → `base/org/identity/secret_credentials#update`
- `PUT /identity/secrets/:id(.:format)` → `base/org/identity/secret_credentials#update`
- `DELETE /identity/secrets/:id(.:format)` → `base/org/identity/secret_credentials#destroy`
- `GET /identity/sessions(.:format)` → `base/org/identity/sessions#index` [base_org_identity_sessions]
- `GET /identity/sessions/:id(.:format)` → `base/org/identity/sessions#show` [base_org_identity_session]
- `GET /identity/activities(.:format)` → `base/org/identity/activities#index` [base_org_identity_activities]
- `GET /identity/withdrawal(.:format)` → `base/org/identity/withdrawals#show` [base_org_identity_withdrawal]

### tech_staff — 10 route objects

- `GET /` → `tech/org/roots#index` [tech_org_root]
- `GET /dashboard(.:format)` → `tech/org/dashboards#show` [tech_org_dashboard]
- `GET /revision` → `tech/org/revisions#show` [tech_org_revision]
- `GET /health` → `tech/org/healths#show` [tech_org_health]
- `GET /health/liveness` → `tech/org/health/livenesses#show` [tech_org_health_liveness]
- `GET /health/readiness` → `tech/org/health/readinesses#show` [tech_org_health_readiness]
- `GET /health/startup` → `tech/org/health/startups#show` [tech_org_health_startup]
- `POST /csp-violation-report(.:format)` → `tech/org/csp_violation_reports#create` [tech_org_csp_violation_report]
- `GET /api/v0/health.json` → `tech/org/api/v0/healths#show` [tech_org_api_v0_health]
- `GET /api/v0/revision.json` → `tech/org/api/v0/revisions#show` [tech_org_api_v0_revision]

### mission — 1 route objects

- `MOUNT /` → `mount `mission_control_jobs`` [mission_control_jobs]

### flipper — 1 route objects

- `MOUNT /` → `mount `flipper`` [flipper]

### blazer — 1 route objects

- `MOUNT /` → `mount `blazer`` [blazer]

### pghero — 1 route objects

- `MOUNT /` → `mount `pghero`` [pghero]

### swagger — 2 route objects

- `MOUNT /openapi` → `mount `rswag_api`` [rswag_api]
- `MOUNT /` → `mount `rswag_ui`` [rswag_ui]

### coverband — 0 route objects

No route object was present in this runtime. The OWN operator route definition remains; its Coverband Rack app was not loaded by the runtime guard for this `bin/rails routes` run.


### unknown_host_fallback — 1 route objects

- `GET /` → `unknown_hosts#show`

### development_framework — 8 route objects

- `GET /_inertia/devtools/entries` → `inertia_rails/devtools/entries#index`
- `GET /_inertia/devtools/entries/:id` → `inertia_rails/devtools/entries#show`
- `GET /rails/info/properties(.:format)` → `rails/info#properties` [rails_info_properties]
- `GET /rails/info/routes(.:format)` → `rails/info#routes` [rails_info_routes]
- `GET /rails/info/notes(.:format)` → `rails/info#notes` [rails_info_notes]
- `GET /rails/info(.:format)` → `rails/info#index` [rails_info]
- `GET /.well-known/appspecific/com.chrome.devtools.json(.:format)` → `rails/devtools#show`
- `GET /` → `rails/welcome#index`

Foreign surface route records after excluding Rails development diagnostics: 0. Social/OAuth callback route records: 0.

## Mounted engine routes expanded by `bin/rails routes`

## Mounted operator-engine routes expanded by `bin/rails routes`

These nested routes inherit the host constraint of their mount. Rails route-object counts above count each mount once; the Rails CLI also expands these engine routes.

### Mission — 24 nested routes

- `application_queue_pause DELETE /applications/:application_id/queues/:queue_id/pause(.:format) mission_control/jobs/queues/pauses#destroy`
- `POST   /applications/:application_id/queues/:queue_id/pause(.:format) mission_control/jobs/queues/pauses#create`
- `application_queues GET    /applications/:application_id/queues(.:format)                 mission_control/jobs/queues#index`
- `application_queue GET    /applications/:application_id/queues/:id(.:format)             mission_control/jobs/queues#show`
- `application_job_retry POST   /applications/:application_id/jobs/:job_id/retry(.:format)     mission_control/jobs/retries#create`
- `application_job_discard POST   /applications/:application_id/jobs/:job_id/discard(.:format)   mission_control/jobs/discards#create`
- `application_job_dispatch POST   /applications/:application_id/jobs/:job_id/dispatch(.:format)  mission_control/jobs/dispatches#create`
- `application_bulk_retries POST   /applications/:application_id/jobs/bulk_retries(.:format)      mission_control/jobs/bulk_retries#create`
- `application_bulk_discards POST   /applications/:application_id/jobs/bulk_discards(.:format)     mission_control/jobs/bulk_discards#create`
- `application_job GET    /applications/:application_id/jobs/:id(.:format)               mission_control/jobs/jobs#show`
- `application_jobs GET    /applications/:application_id/:status/jobs(.:format)           mission_control/jobs/jobs#index`
- `application_workers GET    /applications/:application_id/workers(.:format)                mission_control/jobs/workers#index`
- `application_worker GET    /applications/:application_id/workers/:id(.:format)            mission_control/jobs/workers#show`
- `application_recurring_tasks GET    /applications/:application_id/recurring_tasks(.:format)        mission_control/jobs/recurring_tasks#index`
- `application_recurring_task GET    /applications/:application_id/recurring_tasks/:id(.:format)    mission_control/jobs/recurring_tasks#show`
- `PATCH  /applications/:application_id/recurring_tasks/:id(.:format)    mission_control/jobs/recurring_tasks#update`
- `PUT    /applications/:application_id/recurring_tasks/:id(.:format)    mission_control/jobs/recurring_tasks#update`
- `application_batches GET    /applications/:application_id/batches(.:format)                mission_control/jobs/batches#index`
- `application_batch GET    /applications/:application_id/batches/:id(.:format)            mission_control/jobs/batches#show`
- `queues GET    /queues(.:format)                                              mission_control/jobs/queues#index`
- `queue GET    /queues/:id(.:format)                                          mission_control/jobs/queues#show`
- `job GET    /jobs/:id(.:format)                                            mission_control/jobs/jobs#show`
- `jobs GET    /:status/jobs(.:format)                                        mission_control/jobs/jobs#index`
- `root GET    /                                                              mission_control/jobs/queues#index`

### Blazer — 31 nested routes

- `run_queries POST   /queries/run(.:format)            blazer/queries#run`
- `cancel_queries POST   /queries/cancel(.:format)         blazer/queries#cancel`
- `refresh_query POST   /queries/:id/refresh(.:format)    blazer/queries#refresh`
- `tables_queries GET    /queries/tables(.:format)         blazer/queries#tables`
- `schema_queries GET    /queries/schema(.:format)         blazer/queries#schema`
- `docs_queries GET    /queries/docs(.:format)           blazer/queries#docs`
- `queries GET    /queries(.:format)                blazer/queries#index`
- `POST   /queries(.:format)                blazer/queries#create`
- `new_query GET    /queries/new(.:format)            blazer/queries#new`
- `edit_query GET    /queries/:id/edit(.:format)       blazer/queries#edit`
- `query GET    /queries/:id(.:format)            blazer/queries#show`
- `PATCH  /queries/:id(.:format)            blazer/queries#update`
- `PUT    /queries/:id(.:format)            blazer/queries#update`
- `DELETE /queries/:id(.:format)            blazer/queries#destroy`
- `run_check GET    /checks/:id/run(.:format)         blazer/checks#run`
- `checks GET    /checks(.:format)                 blazer/checks#index`
- `POST   /checks(.:format)                 blazer/checks#create`
- `new_check GET    /checks/new(.:format)             blazer/checks#new`
- `edit_check GET    /checks/:id/edit(.:format)        blazer/checks#edit`
- `check PATCH  /checks/:id(.:format)             blazer/checks#update`
- `PUT    /checks/:id(.:format)             blazer/checks#update`
- `DELETE /checks/:id(.:format)             blazer/checks#destroy`
- `refresh_dashboard POST   /dashboards/:id/refresh(.:format) blazer/dashboards#refresh`
- `dashboards POST   /dashboards(.:format)             blazer/dashboards#create`
- `new_dashboard GET    /dashboards/new(.:format)         blazer/dashboards#new`
- `edit_dashboard GET    /dashboards/:id/edit(.:format)    blazer/dashboards#edit`
- `dashboard GET    /dashboards/:id(.:format)         blazer/dashboards#show`
- `PATCH  /dashboards/:id(.:format)         blazer/dashboards#update`
- `PUT    /dashboards/:id(.:format)         blazer/dashboards#update`
- `DELETE /dashboards/:id(.:format)         blazer/dashboards#destroy`
- `root GET    /                                 blazer/queries#home`

### PgHero — 25 nested routes

- `space GET  (/:database)/space(.:format)                     pg_hero/home#space`
- `relation_space GET  (/:database)/space/:relation(.:format)           pg_hero/home#relation_space`
- `index_bloat GET  (/:database)/index_bloat(.:format)               pg_hero/home#index_bloat`
- `live_queries GET  (/:database)/live_queries(.:format)              pg_hero/home#live_queries`
- `queries GET  (/:database)/queries(.:format)                   pg_hero/home#queries`
- `show_query GET  (/:database)/queries/:query_hash(.:format)       pg_hero/home#show_query`
- `system GET  (/:database)/system(.:format)                    pg_hero/home#system`
- `cpu_usage GET  (/:database)/cpu_usage(.:format)                 pg_hero/home#cpu_usage`
- `connection_stats GET  (/:database)/connection_stats(.:format)          pg_hero/home#connection_stats`
- `replication_lag_stats GET  (/:database)/replication_lag_stats(.:format)     pg_hero/home#replication_lag_stats`
- `load_stats GET  (/:database)/load_stats(.:format)                pg_hero/home#load_stats`
- `free_space_stats GET  (/:database)/free_space_stats(.:format)          pg_hero/home#free_space_stats`
- `explain GET  (/:database)/explain(.:format)                   pg_hero/home#explain`
- `tune GET  (/:database)/tune(.:format)                      pg_hero/home#tune`
- `connections GET  (/:database)/connections(.:format)               pg_hero/home#connections`
- `maintenance GET  (/:database)/maintenance(.:format)               pg_hero/home#maintenance`
- `kill POST (/:database)/kill(.:format)                      pg_hero/home#kill`
- `kill_long_running_queries POST (/:database)/kill_long_running_queries(.:format) pg_hero/home#kill_long_running_queries`
- `kill_all POST (/:database)/kill_all(.:format)                  pg_hero/home#kill_all`
- `enable_query_stats POST (/:database)/enable_query_stats(.:format)        pg_hero/home#enable_query_stats`
- `POST (/:database)/explain(.:format)                   pg_hero/home#explain`
- `reset_query_stats POST (/:database)/reset_query_stats(.:format)         pg_hero/home#reset_query_stats`
- `system_stats GET  (/:database)/system_stats(.:format)              redirect(301, system)`
- `query_stats GET  (/:database)/query_stats(.:format)               redirect(301, queries)`
- `root GET  /(:database)(.:format)                           pg_hero/home#index`

### Swagger API — 0 nested routes

No nested route is defined in this runtime.

### Swagger UI — 0 nested routes

No nested route is defined in this runtime.

## B4 controller file lists

## B4 report-only controller classification

Classified 88 surviving Base app/org controller files. These controller files were not changed in this round; the report distinguishes future RP boundaries, identity data ownership, and Access ceremony/provider candidates. Earlier hard-reset deletions of removed callback/sign-in controllers remain deleted.

### (a) Future relying-party boundary — preserve for later Access reconnection

The pre/full access controllers define the RP boundary once Base is reconnected to Access. They are not currently reachable in the route inventory.

- `app/controllers/base/app/full_access_controller.rb`
- `app/controllers/base/app/pre_access_controller.rb`
- `app/controllers/base/org/full_access_controller.rb`
- `app/controllers/base/org/pre_access_controller.rb`

### (b) Base-owned identity data management — keep

These controllers manage account/profile, credentials, session inventory, privacy/withdrawal records, organization identity records, and preference state. Secret issuance/presentation endpoints are grouped here as Base-owned credential lifecycle data; they do not issue OIDC authorization codes or tokens.

- `app/controllers/base/app/accounts_controller.rb`
- `app/controllers/base/app/api/v0/identity/selections_controller.rb`
- `app/controllers/base/app/api/v0/identity/standings_controller.rb`
- `app/controllers/base/app/api/v0/preferences/cookies_controller.rb`
- `app/controllers/base/app/api/v0/preferences/themes_controller.rb`
- `app/controllers/base/app/api/v0/preferences/web_pushes_controller.rb`
- `app/controllers/base/app/identity/activities_controller.rb`
- `app/controllers/base/app/identity/base_controller.rb`
- `app/controllers/base/app/identity/birthdates_controller.rb`
- `app/controllers/base/app/identity/emails_controller.rb`
- `app/controllers/base/app/identity/passkeys_controller.rb`
- `app/controllers/base/app/identity/privacy/erasure/statuses_controller.rb`
- `app/controllers/base/app/identity/privacy/erasures_controller.rb`
- `app/controllers/base/app/identity/sessions_controller.rb`
- `app/controllers/base/app/identity/standings_controller.rb`
- `app/controllers/base/app/identity/telephones_controller.rb`
- `app/controllers/base/app/identity/totps_controller.rb`
- `app/controllers/base/app/identity/withdrawals_controller.rb`
- `app/controllers/base/app/preference/calendars_controller.rb`
- `app/controllers/base/app/preference/clocks_controller.rb`
- `app/controllers/base/app/preference/cookies_controller.rb`
- `app/controllers/base/app/preference/currencies_controller.rb`
- `app/controllers/base/app/preference/customizations_controller.rb`
- `app/controllers/base/app/preference/densities_controller.rb`
- `app/controllers/base/app/preference/emails_controller.rb`
- `app/controllers/base/app/preference/languages_controller.rb`
- `app/controllers/base/app/preference/motions_controller.rb`
- `app/controllers/base/app/preference/notifications_controller.rb`
- `app/controllers/base/app/preference/paginations_controller.rb`
- `app/controllers/base/app/preference/regions_controller.rb`
- `app/controllers/base/app/preference/screens_controller.rb`
- `app/controllers/base/app/preference/themes_controller.rb`
- `app/controllers/base/app/preference/timezones_controller.rb`
- `app/controllers/base/app/preferences_base_controller.rb`
- `app/controllers/base/app/preferences_controller.rb`
- `app/controllers/base/app/secret_issuances_controller.rb`
- `app/controllers/base/app/secret_presentations_controller.rb`
- `app/controllers/base/app/secrets_controller.rb`
- `app/controllers/base/org/accounts_controller.rb`
- `app/controllers/base/org/api/v0/identity/selections_controller.rb`
- `app/controllers/base/org/api/v0/identity/standings_controller.rb`
- `app/controllers/base/org/api/v0/preferences/cookies_controller.rb`
- `app/controllers/base/org/api/v0/preferences/themes_controller.rb`
- `app/controllers/base/org/api/v0/preferences/web_pushes_controller.rb`
- `app/controllers/base/org/api/v0/support/accounts_controller.rb`
- `app/controllers/base/org/identity/activities_controller.rb`
- `app/controllers/base/org/identity/birthdates_controller.rb`
- `app/controllers/base/org/identity/emails_controller.rb`
- `app/controllers/base/org/identity/passkeys_controller.rb`
- `app/controllers/base/org/identity/removals_controller.rb`
- `app/controllers/base/org/identity/rotations_controller.rb`
- `app/controllers/base/org/identity/secret_credentials_controller.rb`
- `app/controllers/base/org/identity/sessions_controller.rb`
- `app/controllers/base/org/identity/standings_controller.rb`
- `app/controllers/base/org/identity/telephones_controller.rb`
- `app/controllers/base/org/identity/withdrawals_controller.rb`
- `app/controllers/base/org/preference/calendars_controller.rb`
- `app/controllers/base/org/preference/clocks_controller.rb`
- `app/controllers/base/org/preference/cookies_controller.rb`
- `app/controllers/base/org/preference/currencies_controller.rb`
- `app/controllers/base/org/preference/customizations_controller.rb`
- `app/controllers/base/org/preference/densities_controller.rb`
- `app/controllers/base/org/preference/emails_controller.rb`
- `app/controllers/base/org/preference/languages_controller.rb`
- `app/controllers/base/org/preference/motions_controller.rb`
- `app/controllers/base/org/preference/notifications_controller.rb`
- `app/controllers/base/org/preference/paginations_controller.rb`
- `app/controllers/base/org/preference/regions_controller.rb`
- `app/controllers/base/org/preference/screens_controller.rb`
- `app/controllers/base/org/preference/themes_controller.rb`
- `app/controllers/base/org/preference/timezones_controller.rb`
- `app/controllers/base/org/preferences_base_controller.rb`
- `app/controllers/base/org/preferences_controller.rb`

### (c) Access ceremony/provider code — remove or relocate in a later scoped change

These endpoints run verification/withdrawal re-entry ceremonies or publish the local JWKS provider surface. They remain untouched because B4 is report-only.

- `app/controllers/base/app/identity/withdrawal/sessions_controller.rb`
- `app/controllers/base/app/verification/cancellations_controller.rb`
- `app/controllers/base/app/verification/completions_controller.rb`
- `app/controllers/base/app/verification/setups_controller.rb`
- `app/controllers/base/app/verifications_controller.rb`
- `app/controllers/base/app/well_known/jwks_controller.rb`
- `app/controllers/base/org/verification/cancellations_controller.rb`
- `app/controllers/base/org/verification/completions_controller.rb`
- `app/controllers/base/org/verification/setups_controller.rb`
- `app/controllers/base/org/verifications_controller.rb`
- `app/controllers/base/org/well_known/jwks_controller.rb`

Counts: (a) 4, (b) 73, (c) 11.

## Detailed model references

### `app_setting` — USED

Concrete app models: 29; non-model callers: 27; model/test-only: 2; no scanned caller: 0.

Non-model code references, with one example caller each:

- `AppPreference` — `app/controllers/base/app/application_controller.rb`

- `AppPreferenceBrowserBinding` — `app/controllers/concerns/preference_browser_state_reader.rb`

- `AppPreferenceConsentReceipt` — `app/controllers/concerns/preference_browser_state_reader.rb`

- `AppPreferenceCookie` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceCurrency` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceCurrencyOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceDateFormat` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceDateFormatOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceDensity` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceDensityOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceLanguage` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceLanguageOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceMotion` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceMotionOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferencePageSize` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferencePageSizeOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceRegion` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceRegionOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceStatus` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceTheme` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceThemeOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceTimeFormat` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceTimeFormatOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceTimezone` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceTimezoneOption` — `app/controllers/concerns/preference_class_registry.rb`

- `AppPreferenceWebPush` — `app/controllers/concerns/preference_browser_state_reader.rb`

- `AppPreferenceWebPushOption` — `app/controllers/concerns/preference_browser_state_reader.rb`

Referenced only from another model or a test, with one example caller each:

- `AppPreferenceAdultContentGate` — AppPreference (`app/models/app_preference.rb`)

- `AppPreferenceAdultContentGateOption` — AppPreferenceAdultContentGate (`app/models/app_preference_adult_content_gate.rb`)

### `app_signal` — USED

Concrete app models: 2; non-model callers: 1; model/test-only: 1; no scanned caller: 0.

Non-model code references, with one example caller each:

- `ClientNotificationRecord` — `app/services/retention_cross_database_child_purge.rb`

Referenced only from another model or a test, with one example caller each:

- `MemberNotification` — ClientNotificationRecord (`app/models/client_notification_record.rb`)

### `app_zenith` — USED

Concrete app models: 114; non-model callers: 63; model/test-only: 50; no scanned caller: 1.

Non-model code references, with one example caller each:

- `AppEnforcementAppeal` — `app/jobs/enforcement_reconciliation_job.rb`

- `AppEnforcementCase` — `app/controllers/base/app/api/v0/identity/standings_controller.rb`

- `AppIdentityAuthenticationEvent` — `app/jobs/op_identity_event_delivery_job.rb`

- `Client` — `app/adapters/avatar_authority_client.rb`

- `ClientAuthorityLock` — `app/operations/client_persona_creator.rb`

- `ClientBanner` — `app/queries/current_banner_query.rb`

- `ClientContactAuditOutbox` — `app/jobs/contact_audit_delivery_job.rb`

- `ClientEmail` — `app/controllers/base/app/identity/emails_controller.rb`

- `ClientEmailStatus` — `app/controllers/base/app/identity/emails_controller.rb`

- `ClientEnforcementRecoveryCeremony` — `app/operations/enforcement_case_end_operation.rb`

- `ClientExternalIdentity` — `app/lib/enforcement_identifier_digest.rb`

- `ClientIdentity` — `app/operations/client_persona_creator.rb`

- `ClientIdentityState` — `app/operations/client_persona_creator.rb`

- `ClientPasskey` — `app/controllers/base/app/identity/passkeys_controller.rb`

- `ClientPasskeyAuditOutbox` — `app/jobs/passkey_audit_delivery_job.rb`

- `ClientPasskeyStatus` — `app/operations/client_secret_passkey_reservation_issuer.rb`

- `ClientPersona` — `app/controllers/base/app/api/v0/avatar/avatars_controller.rb`

- `ClientPersonaAuthorityCutover` — `app/queries/authority_owner_migration_inventory.rb`

- `ClientPersonaLifecycle` — `app/operations/client_persona_creator.rb`

- `ClientPersonaOwnership` — `app/operations/client_persona_creator.rb`

- `ClientPreference` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceCurrency` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceCurrencyOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceDateFormat` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceDateFormatOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceDensity` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceDensityOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceLanguage` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceLanguageOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceMotion` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceMotionOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferencePageSize` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferencePageSizeOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceRegion` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceRegionOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceStatus` — `app/controllers/concerns/preference_write_boundary.rb`

- `ClientPreferenceTheme` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceThemeOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceTimeFormat` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceTimeFormatOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceTimezone` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPreferenceTimezoneOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ClientPrivacyRequest` — `app/controllers/base/app/identity/privacy/erasure/statuses_controller.rb`

- `ClientProcessorErasureNotification` — `app/consumers/processor_erasure_notification_receipt_consumer.rb`

- `ClientRetentionHold` — `app/jobs/retention_purge_job.rb`

- `ClientSecretAuditOutbox` — `app/controllers/base/app/secret_issuances_controller.rb`

- `ClientSecretCredential` — `app/controllers/base/app/secret_issuances_controller.rb`

- `ClientSecretIssuance` — `app/controllers/base/app/secret_issuances_controller.rb`

- `ClientSocialAuditOutbox` — `app/operations/withdrawal_personal_data_anonymizer.rb`

- `ClientStatus` — `app/operations/client_persona_creator.rb`

- `ClientTelephone` — `app/controllers/base/app/identity/telephones_controller.rb`

- `ClientTelephoneStatus` — `app/controllers/base/app/identity/telephones_controller.rb`

- `ClientTotpCredential` — `app/controllers/base/app/identity/totps_controller.rb`

- `ClientTotpCredentialStatus` — `app/controllers/base/app/identity/totps_controller.rb`

- `ClientWithdrawalCeremony` — `app/controllers/base/app/identity/privacy/erasure/statuses_controller.rb`

- `ClientWithdrawalFlow` — `app/jobs/retention_purge_job.rb`

- `Enterprise` — `app/controllers/base/app/api/v0/membership/directory_controller.rb`

- `EnterpriseAuthorityCutover` — `app/queries/authority_owner_migration_inventory.rb`

- `EnterpriseLifecycle` — `app/operations/enterprise_creator.rb`

- `EnterpriseOwnership` — `app/operations/enterprise_creator.rb`

- `Member` — `app/jobs/retention_purge_job.rb`

- `PersonaMembership` — `app/policies/organization_membership_policy.rb`

- `PersonaMembershipKind` — `app/resolvers/avatar_permission_resolver.rb`

Referenced only from another model or a test, with one example caller each:

- `AppEnforcementAuthenticationMethodEffect` — AppEnforcementCase (`app/models/app_enforcement_case.rb`)

- `AppEnforcementIdentifierEffect` — AppEnforcementCase (`app/models/app_enforcement_case.rb`)

- `AppEnforcementPrincipalEffect` — AppEnforcementCase (`app/models/app_enforcement_case.rb`)

- `AppEnforcementPrincipalLink` — AppEnforcementCase (`app/models/app_enforcement_case.rb`)

- `ClientAccount` — Client (`app/models/client.rb`)

- `ClientAppleNotificationEvent` — Client (`app/models/client.rb`)

- `ClientBulletin` — Client (`app/models/client.rb`)

- `ClientEmailHistory` — test (`test/jobs/dead_identifier_retention_test.rb`)

- `ClientIdentifierRotationAudit` — test (`test/services/identifier_hmac_maintenance_boundary_test.rb`)

- `ClientMember` — Client (`app/models/client.rb`)

- `ClientMemberDeletion` — Client (`app/models/client.rb`)

- `ClientMemberDiscovery` — Client (`app/models/client.rb`)

- `ClientMemberImpersonation` — Client (`app/models/client.rb`)

- `ClientMemberObservation` — Client (`app/models/client.rb`)

- `ClientMemberRevocation` — Client (`app/models/client.rb`)

- `ClientMemberSuspension` — Client (`app/models/client.rb`)

- `ClientMembership` — Client (`app/models/client.rb`)

- `ClientMfaStatus` — Client (`app/models/client.rb`)

- `ClientOidcIdentityBinding` — ClientIdentity (`app/models/client_identity.rb`)

- `ClientPersonaAdministrationGrant` — Client (`app/models/client.rb`)

- `ClientPersonaDelegationGrant` — Client (`app/models/client.rb`)

- `ClientPersonaOwnershipTransferRequest` — ClientPersona (`app/models/client_persona.rb`)

- `ClientPersonaUsageGrant` — Client (`app/models/client.rb`)

- `ClientPersonaViewGrant` — Client (`app/models/client.rb`)

- `ClientPreferenceAdultContentGate` — ClientPreference (`app/models/client_preference.rb`)

- `ClientPreferenceAdultContentGateOption` — ClientPreferenceAdultContentGate (`app/models/client_preference_adult_content_gate.rb`)

- `ClientPrivacyRequestStatus` — ClientPrivacyRequest (`app/models/client_privacy_request.rb`)

- `ClientProcessorErasureNotificationAttempt` — ClientProcessorErasureNotification (`app/models/client_processor_erasure_notification.rb`)

- `ClientProcessorErasureNotificationStatus` — ClientProcessorErasureNotification (`app/models/client_processor_erasure_notification.rb`)

- `ClientProfile` — Client (`app/models/client.rb`)

- `ClientProfileStatus` — ClientProfile (`app/models/client_profile.rb`)

- `ClientRegistrationCompletion` — ClientRegistrationCompletionMethod (`app/models/client_registration_completion_method.rb`)

- `ClientRegistrationCompletionMethod` — ClientRegistrationCompletion (`app/models/client_registration_completion.rb`)

- `ClientRetentionHoldStatus` — ClientRetentionHold (`app/models/client_retention_hold.rb`)

- `ClientSecurityMode` — Client (`app/models/client.rb`)

- `ClientTelephoneHistory` — test (`test/jobs/dead_identifier_retention_test.rb`)

- `ClientVisibility` — Client (`app/models/client.rb`)

- `ClientWithdrawalFlowEvent` — ClientWithdrawalFlow (`app/models/client_withdrawal_flow.rb`)

- `ClientWithdrawalFlowStatus` — ClientWithdrawalFlow (`app/models/client_withdrawal_flow.rb`)

- `CoreAppClientBridge` — Client (`app/models/client.rb`)

- `EnterpriseAdministrationGrant` — Client (`app/models/client.rb`)

- `EnterpriseDelegationGrant` — Client (`app/models/client.rb`)

- `EnterpriseOwnershipTransferRequest` — Enterprise (`app/models/enterprise.rb`)

- `EnterpriseUnit` — Enterprise (`app/models/enterprise.rb`)

- `EnterpriseUnitClosure` — EnterpriseUnit (`app/models/enterprise_unit.rb`)

- `EnterpriseViewGrant` — Client (`app/models/client.rb`)

- `MemberStatus` — Member (`app/models/member.rb`)

- `PersonaAssignment` — ClientIdentity (`app/models/client_identity.rb`)

- `PersonaMembershipRevokeReason` — PersonaMembership (`app/models/persona_membership.rb`)

- `PersonaMembershipState` — PersonaMembership (`app/models/persona_membership.rb`)

No non-model, model-association, or exact-name test reference found:

`ClientSocialLinkSourceReceipt`

### `avatar` — USED

Concrete app models: 45; non-model callers: 30; model/test-only: 15; no scanned caller: 0.

Non-model code references, with one example caller each:

- `Avatar` — `app/adapters/avatar_authority_client.rb`

- `AvatarAgentBinding` — `app/services/avatar_backfill/audit_legacy_client_bindings.rb`

- `AvatarAssignment` — `app/services/retention_cross_database_child_purge.rb`

- `AvatarBlock` — `app/controllers/base/app/api/v0/avatar/social_edges_controller.rb`

- `AvatarBureauAgentGrant` — `app/operations/avatar_access_grants/issue_operation.rb`

- `AvatarBureauOwnershipPeriod` — `app/operations/avatar_access_grants/issue_operation.rb`

- `AvatarBureauToBureauTransferDetail` — `app/operations/avatar_ownership_transfers/registry_accept_operation.rb`

- `AvatarBureauToEnterpriseTransferDetail` — `app/operations/avatar_ownership_transfers/registry_accept_operation.rb`

- `AvatarCapability` — `app/services/avatar_provisioning/create.rb`

- `AvatarEnterpriseOwnershipPeriod` — `app/operations/avatar_access_grants/issue_operation.rb`

- `AvatarEnterprisePersonaGrant` — `app/operations/avatar_access_grants/issue_operation.rb`

- `AvatarEnterpriseToBureauTransferDetail` — `app/operations/avatar_ownership_transfers/registry_accept_operation.rb`

- `AvatarEnterpriseToEnterpriseTransferDetail` — `app/operations/avatar_ownership_transfers/registry_accept_operation.rb`

- `AvatarFollow` — `app/controllers/base/app/api/v0/avatar/social_edges_controller.rb`

- `AvatarGroup` — `app/operations/avatar_group_concrete_ownership_backfill_operation.rb`

- `AvatarGroupConcreteOwnershipPeriod` — `app/operations/avatar_group_concrete_ownership_backfill_operation.rb`

- `AvatarGroupOwnershipPeriod` — `app/operations/avatar_group_concrete_ownership_backfill_operation.rb`

- `AvatarLifecycleState` — `app/operations/avatar_ownership_transfers/operation.rb`

- `AvatarMoniker` — `app/operations/avatar_moniker_writer_operation.rb`

- `AvatarMute` — `app/controllers/base/app/api/v0/avatar/social_edges_controller.rb`

- `AvatarOwnershipCutover` — `app/controllers/base/app/api/v0/avatar/avatar_ownership_transfers_controller.rb`

- `AvatarOwnershipPeriod` — `app/operations/avatar_concrete_ownership_backfill_operation.rb`

- `AvatarOwnershipStatus` — `app/operations/avatar_ownership_transfers/accept_operation.rb`

- `AvatarOwnershipTransfer` — `app/operations/avatar_ownership_transfers/accept_operation.rb`

- `AvatarPersonaBinding` — `app/controllers/base/app/api/v0/avatar/avatars_controller.rb`

- `AvatarPurgeDeferral` — `app/jobs/retention_purge_job.rb`

- `AvatarTransferReservation` — `app/controllers/base/app/api/v0/avatar/avatar_ownership_transfers_controller.rb`

- `GroupAvatarMembership` — `app/controllers/base/app/api/v0/avatar/group_avatar_memberships_controller.rb`

- `Handle` — `app/controllers/base/app/api/v0/avatar/avatars_controller.rb`

- `HandleStatus` — `app/services/avatar_provisioning/create.rb`

Referenced only from another model or a test, with one example caller each:

- `AvatarLifecycleEvent` — Avatar (`app/models/avatar.rb`)

- `AvatarMembership` — Avatar (`app/models/avatar.rb`)

- `AvatarMembershipStatus` — AvatarMembership (`app/models/avatar_membership.rb`)

- `AvatarPermission` — AvatarRole (`app/models/avatar_role.rb`)

- `AvatarRole` — AvatarMembership (`app/models/avatar_membership.rb`)

- `AvatarRolePermission` — AvatarPermission (`app/models/avatar_permission.rb`)

- `HandleAssignment` — Avatar (`app/models/avatar.rb`)

- `HandleAssignmentStatus` — HandleAssignment (`app/models/handle_assignment.rb`)

- `MemberAvatarAccess` — Avatar (`app/models/avatar.rb`)

- `MemberAvatarDeletion` — Avatar (`app/models/avatar.rb`)

- `MemberAvatarExtraction` — Avatar (`app/models/avatar.rb`)

- `MemberAvatarImpersonation` — Avatar (`app/models/avatar.rb`)

- `MemberAvatarOversight` — Avatar (`app/models/avatar.rb`)

- `MemberAvatarSuspension` — Avatar (`app/models/avatar.rb`)

- `MemberAvatarVisibility` — Avatar (`app/models/avatar.rb`)

### `chronicle` — USED

Concrete app models: 22; non-model callers: 21; model/test-only: 1; no scanned caller: 0.

Non-model code references, with one example caller each:

- `AccountAccessEvent` — `app/jobs/enforcement_reconciliation_job.rb`

- `AppPreferenceChronicle` — `app/controllers/concerns/authentication_audit_writer.rb`

- `AppPreferenceChronicleEvent` — `app/controllers/concerns/authentication_audit_writer.rb`

- `AppPreferenceChronicleLevel` — `app/controllers/concerns/preference_class_registry.rb`

- `Chronicle` — `app/adapters/otp_adapter.rb`

- `ChronicleOutboxEntry` — `app/controllers/concerns/authentication_audit_writer.rb`

- `ChronicleRetentionPolicy` — `app/jobs/client_secret_audit_delivery_job.rb`

- `ChronicleVisibility` — `app/operations/chronicle_intent_writer.rb`

- `ChronicleVisibilityContext` — `app/operations/chronicle_intent_writer.rb`

- `ClientChronicle` — `app/controllers/base/app/identity/activities_controller.rb`

- `ClientChronicleEvent` — `app/controllers/concerns/authentication_audit_writer.rb`

- `ClientChronicleLevel` — `app/controllers/concerns/authentication_audit_writer.rb`

- `ComPreferenceChronicle` — `app/controllers/concerns/authentication_audit_writer.rb`

- `ComPreferenceChronicleEvent` — `app/controllers/concerns/authentication_audit_writer.rb`

- `ComPreferenceChronicleLevel` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorChronicle` — `app/controllers/base/org/identity/activities_controller.rb`

- `OperatorChronicleEvent` — `app/controllers/concerns/authentication_audit_writer.rb`

- `OperatorChronicleLevel` — `app/controllers/concerns/authentication_audit_writer.rb`

- `OrgPreferenceChronicle` — `app/controllers/concerns/authentication_audit_writer.rb`

- `OrgPreferenceChronicleEvent` — `app/controllers/concerns/authentication_audit_writer.rb`

- `OrgPreferenceChronicleLevel` — `app/controllers/concerns/preference_class_registry.rb`

Referenced only from another model or a test, with one example caller each:

- `EnforcementEvent` — test (`test/concurrency/enforcement_reconciliation_end_race_test.rb`)

### `com_setting` — USED

Concrete app models: 29; non-model callers: 27; model/test-only: 2; no scanned caller: 0.

Non-model code references, with one example caller each:

- `ComPreference` — `app/controllers/base/com/application_controller.rb`

- `ComPreferenceBrowserBinding` — `app/controllers/concerns/preference_browser_binding.rb`

- `ComPreferenceConsentReceipt` — `app/controllers/concerns/preference_browser_binding.rb`

- `ComPreferenceCookie` — `app/controllers/concerns/preference_browser_binding.rb`

- `ComPreferenceCurrency` — `app/controllers/concerns/com_preference_screen_writes.rb`

- `ComPreferenceCurrencyOption` — `app/controllers/concerns/com_preference_screen_writes.rb`

- `ComPreferenceDateFormat` — `app/controllers/concerns/com_preference_screen_writes.rb`

- `ComPreferenceDateFormatOption` — `app/controllers/concerns/com_preference_screen_writes.rb`

- `ComPreferenceDensity` — `app/controllers/concerns/com_selectable_preference_screen.rb`

- `ComPreferenceDensityOption` — `app/controllers/concerns/com_selectable_preference_screen.rb`

- `ComPreferenceLanguage` — `app/controllers/concerns/com_preference_screen_writes.rb`

- `ComPreferenceLanguageOption` — `app/controllers/concerns/com_preference_screen_writes.rb`

- `ComPreferenceMotion` — `app/controllers/concerns/com_selectable_preference_screen.rb`

- `ComPreferenceMotionOption` — `app/controllers/concerns/com_selectable_preference_screen.rb`

- `ComPreferencePageSize` — `app/controllers/concerns/com_selectable_preference_screen.rb`

- `ComPreferencePageSizeOption` — `app/controllers/concerns/com_selectable_preference_screen.rb`

- `ComPreferenceRegion` — `app/controllers/base/com/application_controller.rb`

- `ComPreferenceRegionOption` — `app/controllers/base/com/application_controller.rb`

- `ComPreferenceStatus` — `app/controllers/base/com/application_controller.rb`

- `ComPreferenceTheme` — `app/controllers/concerns/preference_class_registry.rb`

- `ComPreferenceThemeOption` — `app/controllers/concerns/preference_class_registry.rb`

- `ComPreferenceTimeFormat` — `app/controllers/concerns/com_preference_screen_writes.rb`

- `ComPreferenceTimeFormatOption` — `app/controllers/concerns/com_preference_screen_writes.rb`

- `ComPreferenceTimezone` — `app/controllers/concerns/com_selectable_preference_screen.rb`

- `ComPreferenceTimezoneOption` — `app/controllers/concerns/com_selectable_preference_screen.rb`

- `ComPreferenceWebPush` — `app/controllers/base/com/api/v0/preferences/web_pushes_controller.rb`

- `ComPreferenceWebPushOption` — `app/controllers/base/com/api/v0/preferences/web_pushes_controller.rb`

Referenced only from another model or a test, with one example caller each:

- `ComPreferenceAdultContentGate` — ComPreference (`app/models/com_preference.rb`)

- `ComPreferenceAdultContentGateOption` — ComPreferenceAdultContentGate (`app/models/com_preference_adult_content_gate.rb`)

### `occurrence` — USED

Concrete app models: 52; non-model callers: 13; model/test-only: 39; no scanned caller: 0.

Non-model code references, with one example caller each:

- `AreaOccurrence` — `app/jobs/retention_purge_job.rb`

- `ClientOccurrence` — `app/jobs/retention_purge_job.rb`

- `ClientOccurrenceStatus` — `app/services/sign_risk_emitter.rb`

- `DomainOccurrence` — `app/jobs/retention_purge_job.rb`

- `EmailOccurrence` — `app/jobs/retention_purge_job.rb`

- `IpOccurrence` — `app/jobs/retention_purge_job.rb`

- `JwtAnomalyEvent` — `app/subscribers/jwt_anomaly_subscriber.rb`

- `JwtOccurrence` — `app/jobs/retention_purge_job.rb`

- `OperatorOccurrence` — `app/jobs/retention_purge_job.rb`

- `OperatorOccurrenceStatus` — `app/services/sign_risk_emitter.rb`

- `TelephoneOccurrence` — `app/jobs/retention_purge_job.rb`

- `VisitorOccurrence` — `app/jobs/retention_purge_job.rb`

- `ZipOccurrence` — `app/jobs/retention_purge_job.rb`

Referenced only from another model or a test, with one example caller each:

- `AreaClientOccurrence` — AreaOccurrence (`app/models/area_occurrence.rb`)

- `AreaDomainOccurrence` — AreaOccurrence (`app/models/area_occurrence.rb`)

- `AreaEmailOccurrence` — AreaOccurrence (`app/models/area_occurrence.rb`)

- `AreaIpOccurrence` — AreaOccurrence (`app/models/area_occurrence.rb`)

- `AreaOccurrenceStatus` — AreaOccurrence (`app/models/area_occurrence.rb`)

- `AreaOperatorOccurrence` — AreaOccurrence (`app/models/area_occurrence.rb`)

- `AreaTelephoneOccurrence` — AreaOccurrence (`app/models/area_occurrence.rb`)

- `AreaVisitorOccurrence` — AreaOccurrence (`app/models/area_occurrence.rb`)

- `AreaZipOccurrence` — AreaOccurrence (`app/models/area_occurrence.rb`)

- `ClientZipOccurrence` — ClientOccurrence (`app/models/client_occurrence.rb`)

- `DomainClientOccurrence` — ClientOccurrence (`app/models/client_occurrence.rb`)

- `DomainEmailOccurrence` — DomainOccurrence (`app/models/domain_occurrence.rb`)

- `DomainIpOccurrence` — DomainOccurrence (`app/models/domain_occurrence.rb`)

- `DomainOccurrenceStatus` — DomainOccurrence (`app/models/domain_occurrence.rb`)

- `DomainOperatorOccurrence` — DomainOccurrence (`app/models/domain_occurrence.rb`)

- `DomainTelephoneOccurrence` — DomainOccurrence (`app/models/domain_occurrence.rb`)

- `DomainZipOccurrence` — DomainOccurrence (`app/models/domain_occurrence.rb`)

- `EmailClientOccurrence` — ClientOccurrence (`app/models/client_occurrence.rb`)

- `EmailIpOccurrence` — EmailOccurrence (`app/models/email_occurrence.rb`)

- `EmailOccurrenceStatus` — EmailOccurrence (`app/models/email_occurrence.rb`)

- `EmailOperatorOccurrence` — EmailOccurrence (`app/models/email_occurrence.rb`)

- `EmailTelephoneOccurrence` — EmailOccurrence (`app/models/email_occurrence.rb`)

- `EmailVisitorOccurrence` — EmailOccurrence (`app/models/email_occurrence.rb`)

- `EmailZipOccurrence` — EmailOccurrence (`app/models/email_occurrence.rb`)

- `IpClientOccurrence` — ClientOccurrence (`app/models/client_occurrence.rb`)

- `IpOccurrenceStatus` — IpOccurrence (`app/models/ip_occurrence.rb`)

- `IpOperatorOccurrence` — IpOccurrence (`app/models/ip_occurrence.rb`)

- `IpTelephoneOccurrence` — IpOccurrence (`app/models/ip_occurrence.rb`)

- `IpVisitorOccurrence` — IpOccurrence (`app/models/ip_occurrence.rb`)

- `IpZipOccurrence` — IpOccurrence (`app/models/ip_occurrence.rb`)

- `JwtOccurrenceStatus` — JwtOccurrence (`app/models/jwt_occurrence.rb`)

- `OperatorClientOccurrence` — ClientOccurrence (`app/models/client_occurrence.rb`)

- `OperatorTelephoneOccurrence` — OperatorOccurrence (`app/models/operator_occurrence.rb`)

- `OperatorZipOccurrence` — OperatorOccurrence (`app/models/operator_occurrence.rb`)

- `TelephoneClientOccurrence` — ClientOccurrence (`app/models/client_occurrence.rb`)

- `TelephoneOccurrenceStatus` — TelephoneOccurrence (`app/models/telephone_occurrence.rb`)

- `TelephoneZipOccurrence` — TelephoneOccurrence (`app/models/telephone_occurrence.rb`)

- `VisitorOccurrenceStatus` — VisitorOccurrence (`app/models/visitor_occurrence.rb`)

- `ZipOccurrenceStatus` — ZipOccurrence (`app/models/zip_occurrence.rb`)

### `op_base_app` — USED

Concrete app models: 65; non-model callers: 41; model/test-only: 19; no scanned caller: 5.

Non-model code references, with one example caller each:

- `ClientAuthAdmissionBinding` — `app/controllers/concerns/base_step_up_intent.rb`

- `ClientAuthCeremonySession` — `app/controllers/concerns/base_step_up_intent.rb`

- `ClientDeviceSession` — `app/controllers/concerns/authentication_current_resource_resolver.rb`

- `ClientDpopProofState` — `app/jobs/dpop_proof_state_purge_job.rb`

- `ClientEmailCeremonyTransaction` — `app/controllers/base/app/identity/withdrawal/sessions_controller.rb`

- `ClientOidcAuthorizationTransaction` — `app/jobs/retention_purge_job.rb`

- `ClientOidcConnection` — `app/operations/oidc_connection_recorder.rb`

- `ClientPasskeyCeremonyTransaction` — `app/operations/identity_passkey_ceremony_transaction_purger.rb`

- `ClientSecretCredentialCeremonyTransaction` — `app/operations/identity_secret_credential_ceremony_transaction_purger.rb`

- `ClientSecretSignInReceipt` — `app/jobs/client_secret_lifecycle_job.rb`

- `ClientSensitiveAdmission` — `app/operations/sensitive_admission_accounting_writer.rb`

- `ClientSensitiveAdmissionAuditAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `ClientSensitiveAdmissionAuditOutbox` — `app/operations/sensitive_admission_accounting_writer.rb`

- `ClientSessionLimitResolutionTransaction` — `app/controllers/concerns/session_limit_gate.rb`

- `ClientSignInFlow` — `app/jobs/client_secret_lifecycle_job.rb`

- `ClientSignUpFlow` — `app/jobs/client_secret_lifecycle_job.rb`

- `ClientStepUpAuditOutbox` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `ClientStepUpAuditOutboxAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `ClientStepUpAuditOutboxDeliveryState` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `ClientStepUpCeremonyTransaction` — `app/controllers/base/app/verification/cancellations_controller.rb`

- `ClientStepUpCommit` — `app/services/credential_security_transition.rb`

- `ClientStepUpContext` — `app/operations/base_step_up_admission_issuer.rb`

- `ClientStepUpContextState` — `app/operations/base_step_up_admission_issuer.rb`

- `ClientStepUpContextTransition` — `app/operations/client_step_up_context_transition_writer.rb`

- `ClientStepUpSession` — `app/jobs/retention_purge_job.rb`

- `ClientTelephoneCeremonyTransaction` — `app/jobs/outbound/sms_delivery_job.rb`

- `ClientToken` — `app/controllers/base/app/identity/sessions_controller.rb`

- `ClientTotpCeremonyTransaction` — `app/operations/identity_step_up_ceremony_transaction_purger.rb`

- `ClientVerification` — `app/controllers/concerns/verification_base.rb`

- `IdentityPasskeyCeremonyCandidate` — `app/operations/identity_passkey_registration_final_committer.rb`

- `IdentitySecretCredentialCeremonyCandidate` — `app/services/identity_secret_credential_ceremony_candidate_store.rb`

- `IdentityTotpCeremonyCandidate` — `app/operations/identity_step_up_ceremony_transaction_purger.rb`

- `OpAppAuthorityStop` — `app/operations/op_authority_stop_committer.rb`

- `OpAppAuthorityStopEpochCutoff` — `app/operations/op_authority_stop_committer.rb`

- `OpAppAuthorityStopGrantTarget` — `app/operations/op_authority_stop_committer.rb`

- `OpAppAuthorityStopRootTarget` — `app/operations/op_authority_stop_committer.rb`

- `OpAppGrant` — `app/controllers/base/app/application_controller.rb`

- `OpAppInboundEventReceipt` — `app/operations/op_identity_event_invalidator.rb`

- `SecurityConsumedJti` — `app/jobs/security_consumed_jti_purge_job.rb`

- `SecurityOneTimeReveal` — `app/jobs/security_one_time_reveal_purge_job.rb`

- `TurnstileReplay` — `app/services/turnstile_replay_store.rb`

Referenced only from another model or a test, with one example caller each:

- `ClientAuthAdmissionBindingStatus` — ClientAuthAdmissionBinding (`app/models/client_auth_admission_binding.rb`)

- `ClientAuthCeremonySessionStatus` — ClientAuthCeremonySession (`app/models/client_auth_ceremony_session.rb`)

- `ClientOidcAuthorizationTransactionStatus` — ClientOidcAuthorizationTransaction (`app/models/client_oidc_authorization_transaction.rb`)

- `ClientSessionLimitResolutionState` — ClientSessionLimitResolutionTransaction (`app/models/client_session_limit_resolution_transaction.rb`)

- `ClientSignInFlowState` — ClientSignInFlow (`app/models/client_sign_in_flow.rb`)

- `ClientSignUpFlowCleanupStatus` — ClientSignUpFlow (`app/models/client_sign_up_flow.rb`)

- `ClientSignUpFlowStatus` — ClientSignUpFlow (`app/models/client_sign_up_flow.rb`)

- `ClientSocialCeremonyTransaction` — ClientVisaSocialLinkAdmission (`app/models/client_visa_social_link_admission.rb`)

- `ClientTokenBindingMethod` — ClientToken (`app/models/client_token.rb`)

- `ClientTokenDbscStatus` — ClientToken (`app/models/client_token.rb`)

- `ClientTokenKind` — ClientToken (`app/models/client_token.rb`)

- `ClientTokenStatus` — ClientToken (`app/models/client_token.rb`)

- `LogoutTransaction` — test (`test/models/logout_transaction_test.rb`)

- `OpAppAuthorityStopCause` — OpAppAuthorityStop (`app/models/op_app_authority_stop.rb`)

- `OpAppAuthorityStopParticipant` — OpAppAuthorityStop (`app/models/op_app_authority_stop.rb`)

- `OpAppAuthorityStopParticipantStatus` — OpAppAuthorityStopParticipant (`app/models/op_app_authority_stop_participant.rb`)

- `OpAppAuthorityStopScope` — OpAppAuthorityStop (`app/models/op_app_authority_stop.rb`)

- `OpAppConsumedJti` — test (`test/models/model_table_fixture_consistency_test.rb`)

- `OpAppGrantLogoutHint` — OpAppGrant (`app/models/op_app_grant.rb`)

No non-model, model-association, or exact-name test reference found:

`ClientEmergencySignInOperation`, `ClientOauthCallbackState`, `ClientVisaSensitiveAdmission`, `ClientVisaSocialLinkAdmission`, `IdentitySocialCeremonyCandidate`

### `op_base_org` — USED

Concrete app models: 53; non-model callers: 35; model/test-only: 16; no scanned caller: 2.

Non-model code references, with one example caller each:

- `OpOrgAuthorityStop` — `app/operations/op_authority_stop_committer.rb`

- `OpOrgAuthorityStopEpochCutoff` — `app/operations/op_authority_stop_committer.rb`

- `OpOrgAuthorityStopGrantTarget` — `app/operations/op_authority_stop_committer.rb`

- `OpOrgAuthorityStopRootTarget` — `app/operations/op_authority_stop_committer.rb`

- `OpOrgGrant` — `app/controllers/base/org/application_controller.rb`

- `OpOrgInboundEventReceipt` — `app/operations/op_identity_event_invalidator.rb`

- `OperatorAuthAdmissionBinding` — `app/controllers/concerns/base_step_up_intent.rb`

- `OperatorAuthCeremonySession` — `app/controllers/concerns/base_step_up_intent.rb`

- `OperatorDeviceSession` — `app/controllers/concerns/authentication_current_resource_resolver.rb`

- `OperatorDpopProofState` — `app/jobs/dpop_proof_state_purge_job.rb`

- `OperatorEmailCeremonyTransaction` — `app/mailers/email/org/otp_mailer.rb`

- `OperatorOidcAuthorizationTransaction` — `app/services/base_auth_admission_coordinator.rb`

- `OperatorOidcConnection` — `app/operations/oidc_connection_recorder.rb`

- `OperatorPasskeyCeremonyCandidate` — `app/operations/identity_passkey_registration_final_committer.rb`

- `OperatorPasskeyCeremonyTransaction` — `app/operations/identity_passkey_ceremony_transaction_purger.rb`

- `OperatorSecretCredentialCeremonyTransaction` — `app/operations/identity_secret_credential_ceremony_transaction_purger.rb`

- `OperatorSensitiveAdmission` — `app/operations/sensitive_admission_accounting_writer.rb`

- `OperatorSensitiveAdmissionAuditAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `OperatorSensitiveAdmissionAuditOutbox` — `app/operations/sensitive_admission_accounting_writer.rb`

- `OperatorSessionLimitResolutionTransaction` — `app/controllers/concerns/session_limit_gate.rb`

- `OperatorSignInFlow` — `app/jobs/retention_purge_job.rb`

- `OperatorSignUpFlow` — `app/jobs/retention_purge_job.rb`

- `OperatorStepUpAuditOutbox` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `OperatorStepUpAuditOutboxAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `OperatorStepUpAuditOutboxDeliveryState` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `OperatorStepUpCeremonyTransaction` — `app/controllers/base/org/verification/cancellations_controller.rb`

- `OperatorStepUpCommit` — `app/services/credential_security_transition.rb`

- `OperatorStepUpContext` — `app/operations/base_step_up_admission_issuer.rb`

- `OperatorStepUpContextState` — `app/operations/base_step_up_admission_issuer.rb`

- `OperatorStepUpContextTransition` — `app/operations/operator_step_up_context_transition_writer.rb`

- `OperatorStepUpSession` — `app/jobs/retention_purge_job.rb`

- `OperatorTelephoneCeremonyTransaction` — `app/jobs/outbound/sms_delivery_job.rb`

- `OperatorToken` — `app/controllers/base/org/identity/sessions_controller.rb`

- `OperatorVerification` — `app/controllers/concerns/verification_base.rb`

- `OrganizationInvitation` — `app/policies/org_registration_policy.rb`

Referenced only from another model or a test, with one example caller each:

- `OpOrgAuthorityStopCause` — OpOrgAuthorityStop (`app/models/op_org_authority_stop.rb`)

- `OpOrgAuthorityStopParticipant` — OpOrgAuthorityStop (`app/models/op_org_authority_stop.rb`)

- `OpOrgAuthorityStopParticipantStatus` — OpOrgAuthorityStopParticipant (`app/models/op_org_authority_stop_participant.rb`)

- `OpOrgAuthorityStopScope` — OpOrgAuthorityStop (`app/models/op_org_authority_stop.rb`)

- `OpOrgConsumedJti` — test (`test/models/model_table_fixture_consistency_test.rb`)

- `OpOrgGrantLogoutHint` — OpOrgGrant (`app/models/op_org_grant.rb`)

- `OperatorAuthAdmissionBindingStatus` — OperatorAuthAdmissionBinding (`app/models/operator_auth_admission_binding.rb`)

- `OperatorAuthCeremonySessionStatus` — OperatorAuthCeremonySession (`app/models/operator_auth_ceremony_session.rb`)

- `OperatorOidcAuthorizationTransactionStatus` — OperatorOidcAuthorizationTransaction (`app/models/operator_oidc_authorization_transaction.rb`)

- `OperatorSessionLimitResolutionState` — OperatorSessionLimitResolutionTransaction (`app/models/operator_session_limit_resolution_transaction.rb`)

- `OperatorSignInFlowState` — OperatorSignInFlow (`app/models/operator_sign_in_flow.rb`)

- `OperatorSignUpFlowStatus` — OperatorSignUpFlow (`app/models/operator_sign_up_flow.rb`)

- `OperatorTokenBindingMethod` — OperatorToken (`app/models/operator_token.rb`)

- `OperatorTokenDbscStatus` — OperatorToken (`app/models/operator_token.rb`)

- `OperatorTokenKind` — OperatorToken (`app/models/operator_token.rb`)

- `OperatorTokenStatus` — OperatorToken (`app/models/operator_token.rb`)

No non-model, model-association, or exact-name test reference found:

`OperatorOauthCallbackState`, `OperatorVisaSensitiveAdmission`

### `org_setting` — USED

Concrete app models: 29; non-model callers: 27; model/test-only: 2; no scanned caller: 0.

Non-model code references, with one example caller each:

- `OrgPreference` — `app/controllers/base/org/application_controller.rb`

- `OrgPreferenceBrowserBinding` — `app/controllers/concerns/preference_browser_state_reader.rb`

- `OrgPreferenceConsentReceipt` — `app/controllers/concerns/preference_browser_state_reader.rb`

- `OrgPreferenceCookie` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceCurrency` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceCurrencyOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceDateFormat` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceDateFormatOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceDensity` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceDensityOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceLanguage` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceLanguageOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceMotion` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceMotionOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferencePageSize` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferencePageSizeOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceRegion` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceRegionOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceStatus` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceTheme` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceThemeOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceTimeFormat` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceTimeFormatOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceTimezone` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceTimezoneOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OrgPreferenceWebPush` — `app/controllers/concerns/preference_browser_state_reader.rb`

- `OrgPreferenceWebPushOption` — `app/controllers/concerns/preference_browser_state_reader.rb`

Referenced only from another model or a test, with one example caller each:

- `OrgPreferenceAdultContentGate` — OrgPreference (`app/models/org_preference.rb`)

- `OrgPreferenceAdultContentGateOption` — OrgPreferenceAdultContentGate (`app/models/org_preference_adult_content_gate.rb`)

### `org_signal` — USED

Concrete app models: 2; non-model callers: 1; model/test-only: 1; no scanned caller: 0.

Non-model code references, with one example caller each:

- `OperatorNotificationRecord` — `app/services/retention_cross_database_child_purge.rb`

Referenced only from another model or a test, with one example caller each:

- `OperatorNotification` — OperatorNotificationRecord (`app/models/operator_notification_record.rb`)

### `org_zenith` — USED

Concrete app models: 97; non-model callers: 58; model/test-only: 38; no scanned caller: 1.

Non-model code references, with one example caller each:

- `Agent` — `app/adapters/org_admin_authority_client.rb`

- `AgentAuthorityCutover` — `app/queries/authority_owner_migration_inventory.rb`

- `AgentLifecycle` — `app/operations/agent_creator.rb`

- `AgentMembership` — `app/policies/organization_membership_policy.rb`

- `AgentMembershipKind` — `app/resolvers/avatar_permission_resolver.rb`

- `AgentOwnership` — `app/operations/agent_creator.rb`

- `Bureau` — `app/controllers/base/org/api/v0/membership/directory_controller.rb`

- `BureauAuthorityCutover` — `app/queries/authority_owner_migration_inventory.rb`

- `BureauLifecycle` — `app/operations/bureau_creator.rb`

- `BureauOwnership` — `app/operations/bureau_creator.rb`

- `Operator` — `app/adapters/org_admin_authority_client.rb`

- `OperatorAuthorityLock` — `app/operations/agent_creator.rb`

- `OperatorBanner` — `app/queries/current_banner_query.rb`

- `OperatorCapabilityGrant` — `app/controllers/base/org/api/v0/iam/grants_controller.rb`

- `OperatorEmail` — `app/controllers/base/org/identity/emails_controller.rb`

- `OperatorEmailHistory` — `app/jobs/retention_purge_job.rb`

- `OperatorEmailStatus` — `app/controllers/base/org/identity/emails_controller.rb`

- `OperatorEntraIdentity` — `app/services/org_operator_lifecycle_execute.rb`

- `OperatorEntraIdentityState` — `app/services/org_operator_lifecycle_execute.rb`

- `OperatorIdentity` — `app/operations/agent_creator.rb`

- `OperatorIdentityState` — `app/operations/agent_creator.rb`

- `OperatorLifecycleRequest` — `app/policies/operator_withdrawal_policy.rb`

- `OperatorPasskey` — `app/controllers/base/org/identity/passkeys_controller.rb`

- `OperatorPasskeyAuditOutbox` — `app/jobs/passkey_audit_delivery_job.rb`

- `OperatorPasskeyStatus` — `app/controllers/concerns/org_second_passkey_gate.rb`

- `OperatorPreference` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceCurrency` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceCurrencyOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceDateFormat` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceDateFormatOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceDensity` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceDensityOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceLanguage` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceLanguageOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceMotion` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceMotionOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferencePageSize` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferencePageSizeOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceRegion` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceRegionOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceStatus` — `app/controllers/concerns/preference_write_boundary.rb`

- `OperatorPreferenceTheme` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceThemeOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceTimeFormat` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceTimeFormatOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceTimezone` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorPreferenceTimezoneOption` — `app/controllers/concerns/preference_class_registry.rb`

- `OperatorSecretCredential` — `app/controllers/base/org/identity/secret_credentials_controller.rb`

- `OperatorSecretCredentialStatus` — `app/operations/identity_secret_credential_ceremony_final_committer.rb`

- `OperatorStatus` — `app/operations/agent_creator.rb`

- `OperatorTelephone` — `app/controllers/base/org/identity/telephones_controller.rb`

- `OperatorTelephoneHistory` — `app/jobs/retention_purge_job.rb`

- `OperatorTelephoneStatus` — `app/controllers/base/org/identity/telephones_controller.rb`

- `OperatorWorkspaceAccount` — `app/jobs/retention_purge_job.rb`

- `OrgEnforcementAppeal` — `app/jobs/enforcement_reconciliation_job.rb`

- `OrgEnforcementCase` — `app/controllers/base/org/api/v0/identity/standings_controller.rb`

- `OrgIamOperationOutcome` — `app/operations/org_iam_audited_commit.rb`

- `OrgIdentityAuthenticationEvent` — `app/jobs/op_identity_event_delivery_job.rb`

Referenced only from another model or a test, with one example caller each:

- `AgentAdministrationGrant` — Agent (`app/models/agent.rb`)

- `AgentAssignment` — Agent (`app/models/agent.rb`)

- `AgentDelegationGrant` — Agent (`app/models/agent.rb`)

- `AgentMembershipRevokeReason` — AgentMembership (`app/models/agent_membership.rb`)

- `AgentMembershipState` — AgentMembership (`app/models/agent_membership.rb`)

- `AgentOwnershipTransferRequest` — Agent (`app/models/agent.rb`)

- `AgentUsageGrant` — Agent (`app/models/agent.rb`)

- `AgentViewGrant` — Agent (`app/models/agent.rb`)

- `BureauAdministrationGrant` — Bureau (`app/models/bureau.rb`)

- `BureauDelegationGrant` — Bureau (`app/models/bureau.rb`)

- `BureauOwnershipTransferRequest` — Bureau (`app/models/bureau.rb`)

- `BureauUnit` — AgentMembership (`app/models/agent_membership.rb`)

- `BureauUnitClosure` — BureauUnit (`app/models/bureau_unit.rb`)

- `BureauViewGrant` — Bureau (`app/models/bureau.rb`)

- `CoreOrgOperatorBridge` — Operator (`app/models/operator.rb`)

- `Department` — Department (`app/models/department.rb`)

- `DepartmentStatus` — Department (`app/models/department.rb`)

- `Division` — DivisionStatus (`app/models/division_status.rb`)

- `DivisionStatus` — Division (`app/models/division.rb`)

- `OperatorAccount` — Operator (`app/models/operator.rb`)

- `OperatorBulletin` — Operator (`app/models/operator.rb`)

- `OperatorMfaStatus` — Operator (`app/models/operator.rb`)

- `OperatorOidcIdentityBinding` — OperatorIdentity (`app/models/operator_identity.rb`)

- `OperatorOrganization` — Department (`app/models/department.rb`)

- `OperatorPreferenceAdultContentGate` — OperatorPreference (`app/models/operator_preference.rb`)

- `OperatorPreferenceAdultContentGateOption` — OperatorPreferenceAdultContentGate (`app/models/operator_preference_adult_content_gate.rb`)

- `OperatorSecretCredentialKind` — OperatorSecretCredential (`app/models/operator_secret_credential.rb`)

- `OperatorSecurityMode` — Operator (`app/models/operator.rb`)

- `OperatorVisibility` — Operator (`app/models/operator.rb`)

- `OperatorWorkspaceAccountMembership` — Operator (`app/models/operator.rb`)

- `OperatorWorkspaceAccountStatus` — OperatorWorkspaceAccount (`app/models/operator_workspace_account.rb`)

- `OrgEnforcementAuthenticationMethodEffect` — OrgEnforcementCase (`app/models/org_enforcement_case.rb`)

- `OrgEnforcementIdentifierEffect` — OrgEnforcementCase (`app/models/org_enforcement_case.rb`)

- `OrgEnforcementPrincipalEffect` — OrgEnforcementCase (`app/models/org_enforcement_case.rb`)

- `OrgEnforcementPrincipalLink` — OrgEnforcementCase (`app/models/org_enforcement_case.rb`)

- `OrganizationEntraConnection` — OperatorEntraIdentity (`app/models/operator_entra_identity.rb`)

- `OrganizationEntraConnectionState` — OrganizationEntraConnection (`app/models/organization_entra_connection.rb`)

- `OrganizationStatus` — OperatorOrganization (`app/models/operator_organization.rb`)

No non-model, model-association, or exact-name test reference found:

`OperatorIdentifierRotationAudit`

### `primary` — USED (framework and mounted-engine models)

The app-model-only scanner reported no concrete app model directly on primary because app models use their own abstract records. Loaded Rails and engine descendants do use primary: Action Text, Active Storage, Blazer and Noticed; 13 framework models were loaded in the inventory.

### `publishing` — USED

Concrete app models: 157; non-model callers: 1; model/test-only: 156; no scanned caller: 0.

Non-model code references, with one example caller each:

- `Publishing::MediaFile` — `lib/tasks/object_storage.rake`

Referenced only from another model or a test, with one example caller each:

- `Publishing::Docs::App::Entry` — Publishing::Docs::App::EntryRevision (`app/models/publishing/docs/app/entry_revision.rb`)

- `Publishing::Docs::App::EntryRevision` — Publishing::Docs::App::Entry (`app/models/publishing/docs/app/entry.rb`)

- `Publishing::Docs::App::EntrySlug` — Publishing::Docs::App::Entry (`app/models/publishing/docs/app/entry.rb`)

- `Publishing::Docs::App::EntryVersion` — Publishing::Docs::App::Entry (`app/models/publishing/docs/app/entry.rb`)

- `Publishing::Docs::App::Publication` — Publishing::Docs::App::Entry (`app/models/publishing/docs/app/entry.rb`)

- `Publishing::Docs::App::RevisionMediaUsage` — Publishing::Docs::App::EntryRevision (`app/models/publishing/docs/app/entry_revision.rb`)

- `Publishing::Docs::App::RevisionMultipleTaxonomyAssignment` — Publishing::Docs::App::EntryRevision (`app/models/publishing/docs/app/entry_revision.rb`)

- `Publishing::Docs::App::RevisionSingleTaxonomyAssignment` — Publishing::Docs::App::EntryRevision (`app/models/publishing/docs/app/entry_revision.rb`)

- `Publishing::Docs::App::TaxonomyTerm` — Publishing::Docs::App::RevisionMultipleTaxonomyAssignment (`app/models/publishing/docs/app/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Docs::App::VersionMediaUsage` — Publishing::Docs::App::EntryVersion (`app/models/publishing/docs/app/entry_version.rb`)

- `Publishing::Docs::App::VersionMultipleTaxonomyAssignment` — Publishing::Docs::App::EntryVersion (`app/models/publishing/docs/app/entry_version.rb`)

- `Publishing::Docs::App::VersionSingleTaxonomyAssignment` — Publishing::Docs::App::EntryVersion (`app/models/publishing/docs/app/entry_version.rb`)

- `Publishing::Docs::App::Vocabulary` — Publishing::Docs::App::RevisionMultipleTaxonomyAssignment (`app/models/publishing/docs/app/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Docs::Com::Entry` — Publishing::Docs::Com::EntryRevision (`app/models/publishing/docs/com/entry_revision.rb`)

- `Publishing::Docs::Com::EntryRevision` — Publishing::Docs::Com::Entry (`app/models/publishing/docs/com/entry.rb`)

- `Publishing::Docs::Com::EntrySlug` — Publishing::Docs::Com::Entry (`app/models/publishing/docs/com/entry.rb`)

- `Publishing::Docs::Com::EntryVersion` — Publishing::Docs::Com::Entry (`app/models/publishing/docs/com/entry.rb`)

- `Publishing::Docs::Com::Publication` — Publishing::Docs::Com::Entry (`app/models/publishing/docs/com/entry.rb`)

- `Publishing::Docs::Com::RevisionMediaUsage` — Publishing::Docs::Com::EntryRevision (`app/models/publishing/docs/com/entry_revision.rb`)

- `Publishing::Docs::Com::RevisionMultipleTaxonomyAssignment` — Publishing::Docs::Com::EntryRevision (`app/models/publishing/docs/com/entry_revision.rb`)

- `Publishing::Docs::Com::RevisionSingleTaxonomyAssignment` — Publishing::Docs::Com::EntryRevision (`app/models/publishing/docs/com/entry_revision.rb`)

- `Publishing::Docs::Com::TaxonomyTerm` — Publishing::Docs::Com::RevisionMultipleTaxonomyAssignment (`app/models/publishing/docs/com/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Docs::Com::VersionMediaUsage` — Publishing::Docs::Com::EntryVersion (`app/models/publishing/docs/com/entry_version.rb`)

- `Publishing::Docs::Com::VersionMultipleTaxonomyAssignment` — Publishing::Docs::Com::EntryVersion (`app/models/publishing/docs/com/entry_version.rb`)

- `Publishing::Docs::Com::VersionSingleTaxonomyAssignment` — Publishing::Docs::Com::EntryVersion (`app/models/publishing/docs/com/entry_version.rb`)

- `Publishing::Docs::Com::Vocabulary` — Publishing::Docs::Com::RevisionMultipleTaxonomyAssignment (`app/models/publishing/docs/com/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Docs::Org::Entry` — Publishing::Docs::Org::EntryRevision (`app/models/publishing/docs/org/entry_revision.rb`)

- `Publishing::Docs::Org::EntryRevision` — Publishing::Docs::Org::Entry (`app/models/publishing/docs/org/entry.rb`)

- `Publishing::Docs::Org::EntrySlug` — Publishing::Docs::Org::Entry (`app/models/publishing/docs/org/entry.rb`)

- `Publishing::Docs::Org::EntryVersion` — Publishing::Docs::Org::Entry (`app/models/publishing/docs/org/entry.rb`)

- `Publishing::Docs::Org::Publication` — Publishing::Docs::Org::Entry (`app/models/publishing/docs/org/entry.rb`)

- `Publishing::Docs::Org::RevisionMediaUsage` — Publishing::Docs::Org::EntryRevision (`app/models/publishing/docs/org/entry_revision.rb`)

- `Publishing::Docs::Org::RevisionMultipleTaxonomyAssignment` — Publishing::Docs::Org::EntryRevision (`app/models/publishing/docs/org/entry_revision.rb`)

- `Publishing::Docs::Org::RevisionSingleTaxonomyAssignment` — Publishing::Docs::Org::EntryRevision (`app/models/publishing/docs/org/entry_revision.rb`)

- `Publishing::Docs::Org::TaxonomyTerm` — Publishing::Docs::Org::RevisionMultipleTaxonomyAssignment (`app/models/publishing/docs/org/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Docs::Org::VersionMediaUsage` — Publishing::Docs::Org::EntryVersion (`app/models/publishing/docs/org/entry_version.rb`)

- `Publishing::Docs::Org::VersionMultipleTaxonomyAssignment` — Publishing::Docs::Org::EntryVersion (`app/models/publishing/docs/org/entry_version.rb`)

- `Publishing::Docs::Org::VersionSingleTaxonomyAssignment` — Publishing::Docs::Org::EntryVersion (`app/models/publishing/docs/org/entry_version.rb`)

- `Publishing::Docs::Org::Vocabulary` — Publishing::Docs::Org::RevisionMultipleTaxonomyAssignment (`app/models/publishing/docs/org/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Help::App::Entry` — Publishing::Help::App::EntryRevision (`app/models/publishing/help/app/entry_revision.rb`)

- `Publishing::Help::App::EntryRevision` — Publishing::Help::App::Entry (`app/models/publishing/help/app/entry.rb`)

- `Publishing::Help::App::EntrySlug` — Publishing::Help::App::Entry (`app/models/publishing/help/app/entry.rb`)

- `Publishing::Help::App::EntryVersion` — Publishing::Help::App::Entry (`app/models/publishing/help/app/entry.rb`)

- `Publishing::Help::App::Publication` — Publishing::Help::App::Entry (`app/models/publishing/help/app/entry.rb`)

- `Publishing::Help::App::RevisionMediaUsage` — Publishing::Help::App::EntryRevision (`app/models/publishing/help/app/entry_revision.rb`)

- `Publishing::Help::App::RevisionMultipleTaxonomyAssignment` — Publishing::Help::App::EntryRevision (`app/models/publishing/help/app/entry_revision.rb`)

- `Publishing::Help::App::RevisionSingleTaxonomyAssignment` — Publishing::Help::App::EntryRevision (`app/models/publishing/help/app/entry_revision.rb`)

- `Publishing::Help::App::TaxonomyTerm` — Publishing::Help::App::RevisionMultipleTaxonomyAssignment (`app/models/publishing/help/app/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Help::App::VersionMediaUsage` — Publishing::Help::App::EntryVersion (`app/models/publishing/help/app/entry_version.rb`)

- `Publishing::Help::App::VersionMultipleTaxonomyAssignment` — Publishing::Help::App::EntryVersion (`app/models/publishing/help/app/entry_version.rb`)

- `Publishing::Help::App::VersionSingleTaxonomyAssignment` — Publishing::Help::App::EntryVersion (`app/models/publishing/help/app/entry_version.rb`)

- `Publishing::Help::App::Vocabulary` — Publishing::Help::App::RevisionMultipleTaxonomyAssignment (`app/models/publishing/help/app/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Help::Com::Entry` — Publishing::Help::Com::EntryRevision (`app/models/publishing/help/com/entry_revision.rb`)

- `Publishing::Help::Com::EntryRevision` — Publishing::Help::Com::Entry (`app/models/publishing/help/com/entry.rb`)

- `Publishing::Help::Com::EntrySlug` — Publishing::Help::Com::Entry (`app/models/publishing/help/com/entry.rb`)

- `Publishing::Help::Com::EntryVersion` — Publishing::Help::Com::Entry (`app/models/publishing/help/com/entry.rb`)

- `Publishing::Help::Com::Publication` — Publishing::Help::Com::Entry (`app/models/publishing/help/com/entry.rb`)

- `Publishing::Help::Com::RevisionMediaUsage` — Publishing::Help::Com::EntryRevision (`app/models/publishing/help/com/entry_revision.rb`)

- `Publishing::Help::Com::RevisionMultipleTaxonomyAssignment` — Publishing::Help::Com::EntryRevision (`app/models/publishing/help/com/entry_revision.rb`)

- `Publishing::Help::Com::RevisionSingleTaxonomyAssignment` — Publishing::Help::Com::EntryRevision (`app/models/publishing/help/com/entry_revision.rb`)

- `Publishing::Help::Com::TaxonomyTerm` — Publishing::Help::Com::RevisionMultipleTaxonomyAssignment (`app/models/publishing/help/com/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Help::Com::VersionMediaUsage` — Publishing::Help::Com::EntryVersion (`app/models/publishing/help/com/entry_version.rb`)

- `Publishing::Help::Com::VersionMultipleTaxonomyAssignment` — Publishing::Help::Com::EntryVersion (`app/models/publishing/help/com/entry_version.rb`)

- `Publishing::Help::Com::VersionSingleTaxonomyAssignment` — Publishing::Help::Com::EntryVersion (`app/models/publishing/help/com/entry_version.rb`)

- `Publishing::Help::Com::Vocabulary` — Publishing::Help::Com::RevisionMultipleTaxonomyAssignment (`app/models/publishing/help/com/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Help::Org::Entry` — Publishing::Help::Org::EntryRevision (`app/models/publishing/help/org/entry_revision.rb`)

- `Publishing::Help::Org::EntryRevision` — Publishing::Help::Org::Entry (`app/models/publishing/help/org/entry.rb`)

- `Publishing::Help::Org::EntrySlug` — Publishing::Help::Org::Entry (`app/models/publishing/help/org/entry.rb`)

- `Publishing::Help::Org::EntryVersion` — Publishing::Help::Org::Entry (`app/models/publishing/help/org/entry.rb`)

- `Publishing::Help::Org::Publication` — Publishing::Help::Org::Entry (`app/models/publishing/help/org/entry.rb`)

- `Publishing::Help::Org::RevisionMediaUsage` — Publishing::Help::Org::EntryRevision (`app/models/publishing/help/org/entry_revision.rb`)

- `Publishing::Help::Org::RevisionMultipleTaxonomyAssignment` — Publishing::Help::Org::EntryRevision (`app/models/publishing/help/org/entry_revision.rb`)

- `Publishing::Help::Org::RevisionSingleTaxonomyAssignment` — Publishing::Help::Org::EntryRevision (`app/models/publishing/help/org/entry_revision.rb`)

- `Publishing::Help::Org::TaxonomyTerm` — Publishing::Help::Org::RevisionMultipleTaxonomyAssignment (`app/models/publishing/help/org/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Help::Org::VersionMediaUsage` — Publishing::Help::Org::EntryVersion (`app/models/publishing/help/org/entry_version.rb`)

- `Publishing::Help::Org::VersionMultipleTaxonomyAssignment` — Publishing::Help::Org::EntryVersion (`app/models/publishing/help/org/entry_version.rb`)

- `Publishing::Help::Org::VersionSingleTaxonomyAssignment` — Publishing::Help::Org::EntryVersion (`app/models/publishing/help/org/entry_version.rb`)

- `Publishing::Help::Org::Vocabulary` — Publishing::Help::Org::RevisionMultipleTaxonomyAssignment (`app/models/publishing/help/org/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Info::App::Entry` — Publishing::Info::App::EntryRevision (`app/models/publishing/info/app/entry_revision.rb`)

- `Publishing::Info::App::EntryRevision` — Publishing::Info::App::Entry (`app/models/publishing/info/app/entry.rb`)

- `Publishing::Info::App::EntrySlug` — Publishing::Info::App::Entry (`app/models/publishing/info/app/entry.rb`)

- `Publishing::Info::App::EntryVersion` — Publishing::Info::App::Entry (`app/models/publishing/info/app/entry.rb`)

- `Publishing::Info::App::Publication` — Publishing::Info::App::Entry (`app/models/publishing/info/app/entry.rb`)

- `Publishing::Info::App::RevisionMediaUsage` — Publishing::Info::App::EntryRevision (`app/models/publishing/info/app/entry_revision.rb`)

- `Publishing::Info::App::RevisionMultipleTaxonomyAssignment` — Publishing::Info::App::EntryRevision (`app/models/publishing/info/app/entry_revision.rb`)

- `Publishing::Info::App::RevisionSingleTaxonomyAssignment` — Publishing::Info::App::EntryRevision (`app/models/publishing/info/app/entry_revision.rb`)

- `Publishing::Info::App::TaxonomyTerm` — Publishing::Info::App::RevisionMultipleTaxonomyAssignment (`app/models/publishing/info/app/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Info::App::VersionMediaUsage` — Publishing::Info::App::EntryVersion (`app/models/publishing/info/app/entry_version.rb`)

- `Publishing::Info::App::VersionMultipleTaxonomyAssignment` — Publishing::Info::App::EntryVersion (`app/models/publishing/info/app/entry_version.rb`)

- `Publishing::Info::App::VersionSingleTaxonomyAssignment` — Publishing::Info::App::EntryVersion (`app/models/publishing/info/app/entry_version.rb`)

- `Publishing::Info::App::Vocabulary` — Publishing::Info::App::RevisionMultipleTaxonomyAssignment (`app/models/publishing/info/app/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Info::Com::Entry` — Publishing::Info::Com::EntryRevision (`app/models/publishing/info/com/entry_revision.rb`)

- `Publishing::Info::Com::EntryRevision` — Publishing::Info::Com::Entry (`app/models/publishing/info/com/entry.rb`)

- `Publishing::Info::Com::EntrySlug` — Publishing::Info::Com::Entry (`app/models/publishing/info/com/entry.rb`)

- `Publishing::Info::Com::EntryVersion` — Publishing::Info::Com::Entry (`app/models/publishing/info/com/entry.rb`)

- `Publishing::Info::Com::Publication` — Publishing::Info::Com::Entry (`app/models/publishing/info/com/entry.rb`)

- `Publishing::Info::Com::RevisionMediaUsage` — Publishing::Info::Com::EntryRevision (`app/models/publishing/info/com/entry_revision.rb`)

- `Publishing::Info::Com::RevisionMultipleTaxonomyAssignment` — Publishing::Info::Com::EntryRevision (`app/models/publishing/info/com/entry_revision.rb`)

- `Publishing::Info::Com::RevisionSingleTaxonomyAssignment` — Publishing::Info::Com::EntryRevision (`app/models/publishing/info/com/entry_revision.rb`)

- `Publishing::Info::Com::TaxonomyTerm` — Publishing::Info::Com::RevisionMultipleTaxonomyAssignment (`app/models/publishing/info/com/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Info::Com::VersionMediaUsage` — Publishing::Info::Com::EntryVersion (`app/models/publishing/info/com/entry_version.rb`)

- `Publishing::Info::Com::VersionMultipleTaxonomyAssignment` — Publishing::Info::Com::EntryVersion (`app/models/publishing/info/com/entry_version.rb`)

- `Publishing::Info::Com::VersionSingleTaxonomyAssignment` — Publishing::Info::Com::EntryVersion (`app/models/publishing/info/com/entry_version.rb`)

- `Publishing::Info::Com::Vocabulary` — Publishing::Info::Com::RevisionMultipleTaxonomyAssignment (`app/models/publishing/info/com/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Info::Org::Entry` — Publishing::Info::Org::EntryRevision (`app/models/publishing/info/org/entry_revision.rb`)

- `Publishing::Info::Org::EntryRevision` — Publishing::Info::Org::Entry (`app/models/publishing/info/org/entry.rb`)

- `Publishing::Info::Org::EntrySlug` — Publishing::Info::Org::Entry (`app/models/publishing/info/org/entry.rb`)

- `Publishing::Info::Org::EntryVersion` — Publishing::Info::Org::Entry (`app/models/publishing/info/org/entry.rb`)

- `Publishing::Info::Org::Publication` — Publishing::Info::Org::Entry (`app/models/publishing/info/org/entry.rb`)

- `Publishing::Info::Org::RevisionMediaUsage` — Publishing::Info::Org::EntryRevision (`app/models/publishing/info/org/entry_revision.rb`)

- `Publishing::Info::Org::RevisionMultipleTaxonomyAssignment` — Publishing::Info::Org::EntryRevision (`app/models/publishing/info/org/entry_revision.rb`)

- `Publishing::Info::Org::RevisionSingleTaxonomyAssignment` — Publishing::Info::Org::EntryRevision (`app/models/publishing/info/org/entry_revision.rb`)

- `Publishing::Info::Org::TaxonomyTerm` — Publishing::Info::Org::RevisionMultipleTaxonomyAssignment (`app/models/publishing/info/org/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::Info::Org::VersionMediaUsage` — Publishing::Info::Org::EntryVersion (`app/models/publishing/info/org/entry_version.rb`)

- `Publishing::Info::Org::VersionMultipleTaxonomyAssignment` — Publishing::Info::Org::EntryVersion (`app/models/publishing/info/org/entry_version.rb`)

- `Publishing::Info::Org::VersionSingleTaxonomyAssignment` — Publishing::Info::Org::EntryVersion (`app/models/publishing/info/org/entry_version.rb`)

- `Publishing::Info::Org::Vocabulary` — Publishing::Info::Org::RevisionMultipleTaxonomyAssignment (`app/models/publishing/info/org/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::News::App::Entry` — Publishing::News::App::EntryRevision (`app/models/publishing/news/app/entry_revision.rb`)

- `Publishing::News::App::EntryRevision` — Publishing::News::App::Entry (`app/models/publishing/news/app/entry.rb`)

- `Publishing::News::App::EntrySlug` — Publishing::News::App::Entry (`app/models/publishing/news/app/entry.rb`)

- `Publishing::News::App::EntryVersion` — Publishing::News::App::Entry (`app/models/publishing/news/app/entry.rb`)

- `Publishing::News::App::Publication` — Publishing::News::App::Entry (`app/models/publishing/news/app/entry.rb`)

- `Publishing::News::App::RevisionMediaUsage` — Publishing::News::App::EntryRevision (`app/models/publishing/news/app/entry_revision.rb`)

- `Publishing::News::App::RevisionMultipleTaxonomyAssignment` — Publishing::News::App::EntryRevision (`app/models/publishing/news/app/entry_revision.rb`)

- `Publishing::News::App::RevisionSingleTaxonomyAssignment` — Publishing::News::App::EntryRevision (`app/models/publishing/news/app/entry_revision.rb`)

- `Publishing::News::App::TaxonomyTerm` — Publishing::News::App::RevisionMultipleTaxonomyAssignment (`app/models/publishing/news/app/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::News::App::VersionMediaUsage` — Publishing::News::App::EntryVersion (`app/models/publishing/news/app/entry_version.rb`)

- `Publishing::News::App::VersionMultipleTaxonomyAssignment` — Publishing::News::App::EntryVersion (`app/models/publishing/news/app/entry_version.rb`)

- `Publishing::News::App::VersionSingleTaxonomyAssignment` — Publishing::News::App::EntryVersion (`app/models/publishing/news/app/entry_version.rb`)

- `Publishing::News::App::Vocabulary` — Publishing::News::App::RevisionMultipleTaxonomyAssignment (`app/models/publishing/news/app/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::News::Com::Entry` — Publishing::News::Com::EntryRevision (`app/models/publishing/news/com/entry_revision.rb`)

- `Publishing::News::Com::EntryRevision` — Publishing::News::Com::Entry (`app/models/publishing/news/com/entry.rb`)

- `Publishing::News::Com::EntrySlug` — Publishing::News::Com::Entry (`app/models/publishing/news/com/entry.rb`)

- `Publishing::News::Com::EntryVersion` — Publishing::News::Com::Entry (`app/models/publishing/news/com/entry.rb`)

- `Publishing::News::Com::Publication` — Publishing::News::Com::Entry (`app/models/publishing/news/com/entry.rb`)

- `Publishing::News::Com::RevisionMediaUsage` — Publishing::News::Com::EntryRevision (`app/models/publishing/news/com/entry_revision.rb`)

- `Publishing::News::Com::RevisionMultipleTaxonomyAssignment` — Publishing::News::Com::EntryRevision (`app/models/publishing/news/com/entry_revision.rb`)

- `Publishing::News::Com::RevisionSingleTaxonomyAssignment` — Publishing::News::Com::EntryRevision (`app/models/publishing/news/com/entry_revision.rb`)

- `Publishing::News::Com::TaxonomyTerm` — Publishing::News::Com::RevisionMultipleTaxonomyAssignment (`app/models/publishing/news/com/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::News::Com::VersionMediaUsage` — Publishing::News::Com::EntryVersion (`app/models/publishing/news/com/entry_version.rb`)

- `Publishing::News::Com::VersionMultipleTaxonomyAssignment` — Publishing::News::Com::EntryVersion (`app/models/publishing/news/com/entry_version.rb`)

- `Publishing::News::Com::VersionSingleTaxonomyAssignment` — Publishing::News::Com::EntryVersion (`app/models/publishing/news/com/entry_version.rb`)

- `Publishing::News::Com::Vocabulary` — Publishing::News::Com::RevisionMultipleTaxonomyAssignment (`app/models/publishing/news/com/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::News::Org::Entry` — Publishing::News::Org::EntryRevision (`app/models/publishing/news/org/entry_revision.rb`)

- `Publishing::News::Org::EntryRevision` — Publishing::News::Org::Entry (`app/models/publishing/news/org/entry.rb`)

- `Publishing::News::Org::EntrySlug` — Publishing::News::Org::Entry (`app/models/publishing/news/org/entry.rb`)

- `Publishing::News::Org::EntryVersion` — Publishing::News::Org::Entry (`app/models/publishing/news/org/entry.rb`)

- `Publishing::News::Org::Publication` — Publishing::News::Org::Entry (`app/models/publishing/news/org/entry.rb`)

- `Publishing::News::Org::RevisionMediaUsage` — Publishing::News::Org::EntryRevision (`app/models/publishing/news/org/entry_revision.rb`)

- `Publishing::News::Org::RevisionMultipleTaxonomyAssignment` — Publishing::News::Org::EntryRevision (`app/models/publishing/news/org/entry_revision.rb`)

- `Publishing::News::Org::RevisionSingleTaxonomyAssignment` — Publishing::News::Org::EntryRevision (`app/models/publishing/news/org/entry_revision.rb`)

- `Publishing::News::Org::TaxonomyTerm` — Publishing::News::Org::RevisionMultipleTaxonomyAssignment (`app/models/publishing/news/org/revision_multiple_taxonomy_assignment.rb`)

- `Publishing::News::Org::VersionMediaUsage` — Publishing::News::Org::EntryVersion (`app/models/publishing/news/org/entry_version.rb`)

- `Publishing::News::Org::VersionMultipleTaxonomyAssignment` — Publishing::News::Org::EntryVersion (`app/models/publishing/news/org/entry_version.rb`)

- `Publishing::News::Org::VersionSingleTaxonomyAssignment` — Publishing::News::Org::EntryVersion (`app/models/publishing/news/org/entry_version.rb`)

- `Publishing::News::Org::Vocabulary` — Publishing::News::Org::RevisionMultipleTaxonomyAssignment (`app/models/publishing/news/org/revision_multiple_taxonomy_assignment.rb`)

### `rp_base_app` — USED

Concrete app models: 13; non-model callers: 11; model/test-only: 1; no scanned caller: 1.

Non-model code references, with one example caller each:

- `RpBaseAppIdentityBinding` — `app/resolvers/base_zenith_identity_resolver.rb`

- `RpBaseAppOpSessionBinding` — `app/values/rp_step_up_cell_registry.rb`

- `RpBaseAppPrincipal` — `app/resolvers/base_zenith_identity_resolver.rb`

- `RpBaseAppSession` — `app/controllers/base/app/application_controller.rb`

- `RpBaseAppSessionSelection` — `app/controllers/concerns/browser_rp_authentication.rb`

- `RpStepUpAuditOutbox` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `RpStepUpAuditOutboxAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `RpStepUpAuditOutboxDeliveryState` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `RpStepUpState` — `app/values/rp_step_up_cell_registry.rb`

- `RpStepUpStateStatus` — `app/operations/rp_step_up_state_transition_writer.rb`

- `RpStepUpStateTransition` — `app/values/rp_step_up_cell_registry.rb`

Referenced only from another model or a test, with one example caller each:

- `RpBaseAppEventReceipt` — RpBaseAppOpSessionBinding (`app/models/rp_base_app_op_session_binding.rb`)

No non-model, model-association, or exact-name test reference found:

`RpBaseAppCallbackState`

### `rp_base_org` — USED

Concrete app models: 14; non-model callers: 12; model/test-only: 1; no scanned caller: 1.

Non-model code references, with one example caller each:

- `RpBaseOrgIdentityBinding` — `app/resolvers/base_zenith_identity_resolver.rb`

- `RpBaseOrgOpSessionBinding` — `app/values/rp_step_up_cell_registry.rb`

- `RpBaseOrgPrincipal` — `app/resolvers/base_zenith_identity_resolver.rb`

- `RpBaseOrgSession` — `app/controllers/base/org/application_controller.rb`

- `RpBaseOrgSessionAvatarSelection` — `app/services/acme_selectable_context.rb`

- `RpBaseOrgSessionSelection` — `app/controllers/concerns/browser_rp_authentication.rb`

- `RpBaseOrgStepUpAuditOutbox` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `RpBaseOrgStepUpAuditOutboxAttempt` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `RpBaseOrgStepUpAuditOutboxDeliveryState` — `app/values/step_up_audit_outbox_sources_registry.rb`

- `RpBaseOrgStepUpState` — `app/values/rp_step_up_cell_registry.rb`

- `RpBaseOrgStepUpStateStatus` — `app/values/rp_step_up_cell_registry.rb`

- `RpBaseOrgStepUpStateTransition` — `app/values/rp_step_up_cell_registry.rb`

Referenced only from another model or a test, with one example caller each:

- `RpBaseOrgEventReceipt` — RpBaseOrgOpSessionBinding (`app/models/rp_base_org_op_session_binding.rb`)

No non-model, model-association, or exact-name test reference found:

`RpBaseOrgCallbackState`

### `rp_core_app` — ONLY-VIA-MODELS

Concrete app models: 6; non-model callers: 0; model/test-only: 5; no scanned caller: 1.

Referenced only from another model or a test, with one example caller each:

- `RpCoreAppEventReceipt` — RpCoreAppOpSessionBinding (`app/models/rp_core_app_op_session_binding.rb`)

- `RpCoreAppIdentityBinding` — RpCoreAppOpSessionBinding (`app/models/rp_core_app_op_session_binding.rb`)

- `RpCoreAppOpSessionBinding` — RpCoreAppEventReceipt (`app/models/rp_core_app_event_receipt.rb`)

- `RpCoreAppPrincipal` — RpCoreAppIdentityBinding (`app/models/rp_core_app_identity_binding.rb`)

- `RpCoreAppSession` — RpCoreAppOpSessionBinding (`app/models/rp_core_app_op_session_binding.rb`)

No non-model, model-association, or exact-name test reference found:

`RpCoreAppCallbackState`

### `rp_core_org` — ONLY-VIA-MODELS

Concrete app models: 6; non-model callers: 0; model/test-only: 5; no scanned caller: 1.

Referenced only from another model or a test, with one example caller each:

- `RpCoreOrgEventReceipt` — RpCoreOrgOpSessionBinding (`app/models/rp_core_org_op_session_binding.rb`)

- `RpCoreOrgIdentityBinding` — RpCoreOrgOpSessionBinding (`app/models/rp_core_org_op_session_binding.rb`)

- `RpCoreOrgOpSessionBinding` — RpCoreOrgEventReceipt (`app/models/rp_core_org_event_receipt.rb`)

- `RpCoreOrgPrincipal` — RpCoreOrgIdentityBinding (`app/models/rp_core_org_identity_binding.rb`)

- `RpCoreOrgSession` — RpCoreOrgOpSessionBinding (`app/models/rp_core_org_op_session_binding.rb`)

No non-model, model-association, or exact-name test reference found:

`RpCoreOrgCallbackState`

### `rp_edit_org` — ONLY-VIA-MODELS

Concrete app models: 6; non-model callers: 0; model/test-only: 5; no scanned caller: 1.

Referenced only from another model or a test, with one example caller each:

- `RpEditOrgEventReceipt` — RpEditOrgOpSessionBinding (`app/models/rp_edit_org_op_session_binding.rb`)

- `RpEditOrgIdentityBinding` — RpEditOrgOpSessionBinding (`app/models/rp_edit_org_op_session_binding.rb`)

- `RpEditOrgOpSessionBinding` — RpEditOrgEventReceipt (`app/models/rp_edit_org_event_receipt.rb`)

- `RpEditOrgPrincipal` — RpEditOrgIdentityBinding (`app/models/rp_edit_org_identity_binding.rb`)

- `RpEditOrgSession` — RpEditOrgOpSessionBinding (`app/models/rp_edit_org_op_session_binding.rb`)

No non-model, model-association, or exact-name test reference found:

`RpEditOrgCallbackState`

### `rp_palm_app` — ONLY-VIA-MODELS

Concrete app models: 6; non-model callers: 0; model/test-only: 5; no scanned caller: 1.

Referenced only from another model or a test, with one example caller each:

- `RpPalmAppEventReceipt` — RpPalmAppOpSessionBinding (`app/models/rp_palm_app_op_session_binding.rb`)

- `RpPalmAppIdentityBinding` — RpPalmAppOpSessionBinding (`app/models/rp_palm_app_op_session_binding.rb`)

- `RpPalmAppOpSessionBinding` — RpPalmAppEventReceipt (`app/models/rp_palm_app_event_receipt.rb`)

- `RpPalmAppPrincipal` — RpPalmAppIdentityBinding (`app/models/rp_palm_app_identity_binding.rb`)

- `RpPalmAppSession` — RpPalmAppOpSessionBinding (`app/models/rp_palm_app_op_session_binding.rb`)

No non-model, model-association, or exact-name test reference found:

`RpPalmAppCallbackState`

### `rp_tech_org` — USED

Concrete app models: 6; non-model callers: 1; model/test-only: 4; no scanned caller: 1.

Non-model code references, with one example caller each:

- `RpTechOrgSession` — `app/services/rp_request_authenticator.rb`

Referenced only from another model or a test, with one example caller each:

- `RpTechOrgEventReceipt` — RpTechOrgOpSessionBinding (`app/models/rp_tech_org_op_session_binding.rb`)

- `RpTechOrgIdentityBinding` — RpTechOrgOpSessionBinding (`app/models/rp_tech_org_op_session_binding.rb`)

- `RpTechOrgOpSessionBinding` — RpTechOrgEventReceipt (`app/models/rp_tech_org_event_receipt.rb`)

- `RpTechOrgPrincipal` — RpTechOrgIdentityBinding (`app/models/rp_tech_org_identity_binding.rb`)

No non-model, model-association, or exact-name test reference found:

`RpTechOrgCallbackState`

### `rp_warp_app` — ONLY-VIA-MODELS

Concrete app models: 6; non-model callers: 0; model/test-only: 5; no scanned caller: 1.

Referenced only from another model or a test, with one example caller each:

- `RpWarpAppEventReceipt` — RpWarpAppOpSessionBinding (`app/models/rp_warp_app_op_session_binding.rb`)

- `RpWarpAppIdentityBinding` — RpWarpAppOpSessionBinding (`app/models/rp_warp_app_op_session_binding.rb`)

- `RpWarpAppOpSessionBinding` — RpWarpAppEventReceipt (`app/models/rp_warp_app_event_receipt.rb`)

- `RpWarpAppPrincipal` — RpWarpAppIdentityBinding (`app/models/rp_warp_app_identity_binding.rb`)

- `RpWarpAppSession` — RpWarpAppOpSessionBinding (`app/models/rp_warp_app_op_session_binding.rb`)

No non-model, model-association, or exact-name test reference found:

`RpWarpAppCallbackState`

### `rp_warp_org` — ONLY-VIA-MODELS

Concrete app models: 6; non-model callers: 0; model/test-only: 5; no scanned caller: 1.

Referenced only from another model or a test, with one example caller each:

- `RpWarpOrgEventReceipt` — RpWarpOrgOpSessionBinding (`app/models/rp_warp_org_op_session_binding.rb`)

- `RpWarpOrgIdentityBinding` — RpWarpOrgOpSessionBinding (`app/models/rp_warp_org_op_session_binding.rb`)

- `RpWarpOrgOpSessionBinding` — RpWarpOrgEventReceipt (`app/models/rp_warp_org_event_receipt.rb`)

- `RpWarpOrgPrincipal` — RpWarpOrgIdentityBinding (`app/models/rp_warp_org_identity_binding.rb`)

- `RpWarpOrgSession` — RpWarpOrgOpSessionBinding (`app/models/rp_warp_org_op_session_binding.rb`)

No non-model, model-association, or exact-name test reference found:

`RpWarpOrgCallbackState`

### `search` — UNUSED

Concrete app models: 0; non-model callers: 0; model/test-only: 0; no scanned caller: 0.

No concrete app model maps to this abstract record.

## Jump return test baseline repair

The empty `JumpRtReturnPolicy::EDGE_CATALOG` is an intentional consequence of removing Auth, Visa and the other retired local surfaces. The previous test run still expected successful returns from removed issuers or a Base self-edge. Those tests now assert fail-closed `invalid_claim` results for validly signed candidates; malformed URL cases still assert `invalid_url`, and the fetched-JWKS size boundary still distinguishes accepted document sizes from an oversized document. The integration CSRF case now uses a retained Base preference PATCH route and expects the observed 403. No route or graph edge was restored. The targeted Jump suite passed: 118 runs, 215 assertions, 0 failures/errors.

The full rerun changed from 247 failures to 219, resolving these 28 prior Jump-related identifiers with zero new failure identifiers. This follow-up also corrected the unauthenticated rotation test to assert the observed 401/no-redirect response, resolving one `NoMethodError` with no new failure or error IDs.

## Final test failure identifiers

Count: 219. Each listed failure remains after this follow-up.
- `AcceptanceWu02BaseRpStateTest#test_A02-12:_Base_Welcome_and_Selector_work_from_RP_credentials_without_an_Auth_Rails_session` — `test/integration/acceptance_wu02_base_rp_state_test.rb:55`
- `ActionPolicyUsageTest#test_private_mutation_controller_actions_explicitly_call_authorize_or_document_an_exception` — `test/unit/security/action_policy_usage_test.rb:113`
- `ActorSupportLifecycleTest#test_action_policy_receives_current_actor_context_for_authenticated_app_request` — `test/integration/actor_support_lifecycle_test.rb:305`
- `ActorSupportLifecycleTest#test_sequential_app_and_org_requests_rebuild_actor_context_without_cross_surface_leakage` — `test/integration/actor_support_lifecycle_test.rb:331`
- `ActorSupportLifecycleTest#test_sign_app_request_does_not_use_user_preference_record_as_runtime_fallback_and_resets_afterwards` — `test/integration/actor_support_lifecycle_test.rb:182`
- `ActorSupportLifecycleTest#test_sign_org_request_does_not_use_staff_preference_record_as_runtime_fallback_and_resets_afterwards` — `test/integration/actor_support_lifecycle_test.rb:238`
- `AnonymousComWebPushInitializationTest#test_the_read-only_corporate_host_displays_a_valid_shared_JWT_without_preference_DB_or_private_key` — `test/integration/anonymous_com_web_push_initialization_test.rb:609`
- `AnonymousComWebPushInitializationTest#test_the_read-only_corporate_host_does_not_clear_invalid_shared_preference_cookies_or_read_preference_rows` — `test/integration/anonymous_com_web_push_initialization_test.rb:578`
- `ArchitectureBaselineTest#test_baseline_does_not_list_resolved_files` — `test/tooling/architecture_baseline_test.rb:48`
- `AuthenticatedResponseCachePolicyTest#test_a_matching_validator_does_not_let_a_conditional_request_bypass_authentication` — `test/controllers/concerns/authenticated_response_cache_policy_test.rb:42`
- `AuthenticatedResponseCachePolicyTest#test_an_authenticated_HTML_page_is_no-store` — `test/controllers/concerns/authenticated_response_cache_policy_test.rb:30`
- `AuthenticatedResponseCachePolicyTest#test_an_authenticated_Inertia_visit_is_no-store` — `test/support/inertia_page_object.rb:15`
- `AuthenticatedResponseCachePolicyTest#test_detaching_stale_credentials_clears_Inertia_history_on_the_page_that_follows` — `test/controllers/concerns/authenticated_response_cache_policy_test.rb:120`
- `AuthenticatedResponseCachePolicyTest#test_ordinary_authenticated_navigation_does_not_clear_Inertia_history` — `test/controllers/concerns/authenticated_response_cache_policy_test.rb:80`
- `Base::App::AccountsControllerTest#test_index_lists_accounts` — `test/controllers/base/app/accounts_controller_test.rb:31`
- `Base::App::AccountsControllerTest#test_show_rejects_account_outside_the_current_client_membership_set` — `test/controllers/base/app/accounts_controller_test.rb:63`
- `Base::App::AccountsControllerTest#test_show_resolves_by_public_id` — `test/controllers/base/app/accounts_controller_test.rb:45`
- `Base::App::AccountsControllerTest#test_unknown_public_id_returns_404` — `test/controllers/base/app/accounts_controller_test.rb:71`
- `Base::App::BillingsControllerTest#test_index_renders_for_signed_in_clients` — `test/controllers/base/app/billings_controller_test.rb:73`
- `Base::App::DashboardAvatarImagesControllerTest#test_HEAD_returns_the_image_headers_without_the_body` — `test/controllers/base/app/dashboard_avatar_images_controller_test.rb:117`
- `Base::App::DashboardAvatarImagesControllerTest#test_a_session_selection_naming_another_principal's_Avatar_is_refused,_not_defaulted` — `test/controllers/base/app/dashboard_avatar_images_controller_test.rb:212`
- `Base::App::DashboardAvatarImagesControllerTest#test_a_storage_failure_surfaces_as_an_error_instead_of_the_default_image` — `test/controllers/base/app/dashboard_avatar_images_controller_test.rb:236`
- `Base::App::DashboardAvatarImagesControllerTest#test_request_parameters_never_choose_another_principal's_Avatar` — `test/controllers/base/app/dashboard_avatar_images_controller_test.rb:190`
- `Base::App::DashboardAvatarImagesControllerTest#test_serves_the_static_default_image_when_the_required_Avatar_has_no_stored_image` — `test/controllers/base/app/dashboard_avatar_images_controller_test.rb:143`
- `Base::App::DashboardAvatarImagesControllerTest#test_streams_the_selected_Avatar's_stored_image_privately_with_a_revalidated_ETag` — `test/controllers/base/app/dashboard_avatar_images_controller_test.rb:46`
- `Base::App::GroupsControllerTest#test_client_attaches_an_avatar_to_a_selected-account_group` — `test/controllers/base/app/groups_controller_test.rb:140`
- `Base::App::GroupsControllerTest#test_client_creates_and_views_a_group_in_the_selected_account` — `test/controllers/base/app/groups_controller_test.rb:75`
- `Base::App::GroupsControllerTest#test_client_updates_and_archives_a_selected-account_group` — `test/controllers/base/app/groups_controller_test.rb:120`
- `Base::App::GroupsControllerTest#test_index_lists_the_selected_account's_groups,_archived_included,_and_nothing_else` — `test/controllers/base/app/groups_controller_test.rb:57`
- `Base::App::GroupsControllerTest#test_index_renders_groups_through_inertia` — `test/controllers/base/app/groups_controller_test.rb:24`
- `Base::App::GroupsControllerTest#test_membership_request_cannot_assign_a_caller-selected_role` — `test/controllers/base/app/groups_controller_test.rb:155`
- `Base::App::GroupsControllerTest#test_post-cutover_membership_HTTP_mutations_use_concrete_owners` — `test/controllers/base/app/groups_controller_test.rb:293`
- `Base::App::Identity::WithdrawalsControllerTest#test_deactivation_clears_Inertia_history_on_the_page_that_follows_it` — `test/controllers/base/app/identity/withdrawals_controller_test.rb:173`
- `Base::App::Identity::WithdrawalsControllerTest#test_new_renders_the_withdrawal_entry_without_the_deactivation_form_before_the_schedule_is_acknowledged` — `test/controllers/base/app/identity/withdrawals_controller_test.rb:96`
- `Base::App::Identity::WithdrawalsControllerTest#test_new_reveals_the_deactivation_form_once_the_purge_schedule_is_acknowledged` — `test/controllers/base/app/identity/withdrawals_controller_test.rb:103`
- `Base::App::Identity::WithdrawalsControllerTest#test_recovery_page_and_privacy_erasure_pages_are_reachable_once_the_ceremony_is_issued` — `test/controllers/base/app/identity/withdrawals_controller_test.rb:129`
- `Base::App::Identity::WithdrawalsControllerTest#test_update_with_the_purge_acknowledgement_starts_the_withdrawal_request` — `test/controllers/base/app/identity/withdrawals_controller_test.rb:119`
- `Base::App::Identity::WithdrawalsControllerTest#test_update_without_acknowledging_the_purge_schedule_leaves_the_client_active` — `test/controllers/base/app/identity/withdrawals_controller_test.rb:111`
- `Base::App::Organizations::MembershipsControllerTest#test_HTML_membership_index_links_only_to_memberships_the_principal_can_read` — `test/controllers/base/app/organizations/memberships_controller_test.rb:79`
- `Base::App::Organizations::MembershipsControllerTest#test_create_returns_unprocessable_content` — `test/controllers/base/app/organizations/memberships_controller_test.rb:102`
- `Base::App::Organizations::MembershipsControllerTest#test_destroy_returns_no_content` — `test/controllers/base/app/organizations/memberships_controller_test.rb:118`
- `Base::App::Organizations::MembershipsControllerTest#test_edit_renders_the_existing_membership_entry_with_a_parent_link` — `test/controllers/base/app/organizations/memberships_controller_test.rb:56`
- `Base::App::Organizations::MembershipsControllerTest#test_index_returns_empty_json` — `test/controllers/base/app/organizations/memberships_controller_test.rb:34`
- `Base::App::Organizations::MembershipsControllerTest#test_new_renders_the_existing_membership_entry_with_a_parent_link` — `test/controllers/base/app/organizations/memberships_controller_test.rb:43`
- `Base::App::Organizations::MembershipsControllerTest#test_show_returns_empty_json_for_a_membership_the_actor_may_read` — `test/controllers/base/app/organizations/memberships_controller_test.rb:170`
- `Base::App::Organizations::MembershipsControllerTest#test_unauthenticated_cannot_access_memberships` — `test/controllers/base/app/organizations/memberships_controller_test.rb:26`
- `Base::App::Organizations::MembershipsControllerTest#test_update_returns_unprocessable_content` — `test/controllers/base/app/organizations/memberships_controller_test.rb:110`
- `Base::App::OrganizationsControllerTest#test_index_lists_organizations` — `test/controllers/base/app/organizations_controller_test.rb:23`
- `Base::App::OrganizationsControllerTest#test_show_rejects_organization_outside_the_current_client_membership_set` — `test/controllers/base/app/organizations_controller_test.rb:64`
- `Base::App::OrganizationsControllerTest#test_show_resolves_by_public_id` — `test/controllers/base/app/organizations_controller_test.rb:37`
- `Base::App::OrganizationsControllerTest#test_unknown_public_id_returns_404` — `test/controllers/base/app/organizations_controller_test.rb:72`
- `Base::App::RpRootFeatureRefusalTest#test_a_valid_Base_RP_session_receives_a_localized_refusal_for_unavailable_root-dependent_features` — `test/controllers/base/app/rp_root_feature_refusal_test.rb:92`
- `Base::App::SelectorControllerTest#test_unauthenticated_html_selector_request_stays_on_the_authentication_entry` — `test/controllers/base/app/selector_controller_test.rb:35`
- `Base::App::Verification::SetupsControllerTest#test_a_session_whose_root_login_is_no_longer_fresh_cannot_choose_a_method` — `test/controllers/base/app/verification/setups_controller_test.rb:214`
- `Base::App::Verification::SetupsControllerTest#test_an_RP_step-up_start_refusal_is_logged_by_reason_and_returned_as_localized_text` — `test/controllers/base/app/verification/setups_controller_test.rb:108`
- `Base::App::Verification::SetupsControllerTest#test_an_actor_who_already_holds_an_authenticator_is_sent_to_ordinary_verification_instead_of_the_choice` — `test/controllers/base/app/verification/setups_controller_test.rb:159`
- `Base::App::Verification::SetupsControllerTest#test_authenticator_bootstrap_choices_refuse_before_writing_an_admission` — `test/controllers/base/app/verification/setups_controller_test.rb:200`
- `Base::App::Verification::SetupsControllerTest#test_the_choice_refuses_a_missing_or_unsupported_method_without_starting_a_transaction` — `test/controllers/base/app/verification/setups_controller_test.rb:183`
- `Base::App::Verification::SetupsControllerTest#test_the_method_choice_page_lists_passkey,_authenticator_app_and_email_and_changes_nothing` — `test/controllers/base/app/verification/setups_controller_test.rb:138`
- `Base::App::Verification::SetupsControllerTest#test_the_protected_operation_of_an_actor_without_an_authenticator_leads_to_the_Base_method_choice` — `test/controllers/base/app/verification/setups_controller_test.rb:124`
- `Base::Org::AccountsControllerTest#test_index_renders` — `test/controllers/base/org/accounts_controller_test.rb:20`
- `Base::Org::AccountsControllerTest#test_show_rejects_account_outside_the_current_operator_membership_set` — `test/controllers/base/org/accounts_controller_test.rb:39`
- `Base::Org::AccountsControllerTest#test_show_resolves_by_public_id` — `test/controllers/base/org/accounts_controller_test.rb:29`
- `Base::Org::AccountsControllerTest#test_unknown_public_id_returns_404` — `test/controllers/base/org/accounts_controller_test.rb:46`
- `Base::Org::Iam::GrantPagesTest#test_a_grant_detail_offers_revocation_only_to_a_holder_of_iam.capability.revoke` — `test/controllers/base/org/iam/grant_pages_test.rb:95`
- `Base::Org::Iam::GrantPagesTest#test_an_unknown_grant_public_id_is_not_found` — `test/controllers/base/org/iam/grant_pages_test.rb:122`
- `Base::Org::Iam::GrantPagesTest#test_each_grant_state_is_labelled:_revoked,_pending,_and_expired` — `test/controllers/base/org/iam/grant_pages_test.rb:73`
- `Base::Org::Iam::GrantPagesTest#test_iam.capability.read_lists_grants_filtered_by_operator,_without_a_new-grant_action` — `test/controllers/base/org/iam/grant_pages_test.rb:38`
- `Base::Org::Iam::GrantSubmissionsTest#test_a_missing_or_non-UUIDv4_operation_id_is_refused_before_anything_is_granted` — `test/controllers/base/org/iam/grant_submissions_test.rb:153`
- `Base::Org::Iam::GrantSubmissionsTest#test_an_operation_id_reused_for_a_different_grant_is_a_conflict_and_grants_nothing_more` — `test/controllers/base/org/iam/grant_submissions_test.rb:190`
- `Base::Org::Iam::GrantSubmissionsTest#test_ticket_ids_are_accepted_up_to_64_characters_and_refused_at_65_or_with_a_leading_symbol` — `test/controllers/base/org/iam/grant_submissions_test.rb:105`
- `Base::Org::Iam::GrantSubmissionsTest#test_with_Step-Up_the_grant_screen_offers_only_the_non-IAM_capabilities_the_granter_holds` — `test/controllers/base/org/iam/grant_submissions_test.rb:57`
- `Base::Org::Iam::GrantsControllerTest#test_a_granter_delegates_Tech_access_to_another_operator_with_Step-Up_and_an_audit_record` — `test/controllers/base/org/iam/grants_controller_test.rb:103`
- `Base::Org::Iam::GrantsControllerTest#test_a_revoked_grant_stops_the_grantee's_next_request` — `test/controllers/base/org/iam/grants_controller_test.rb:355`
- `Base::Org::Iam::GrantsControllerTest#test_revoking_the_last_holder_of_the_grant_capability_is_refused_and_leaves_the_grant_in_force` — `test/controllers/base/org/iam/grants_controller_test.rb:318`
- `Base::Org::Iam::GrantsControllerTest#test_self-grant,_unknown_capability,_unknown_operator,_and_out-of-list_durations_are_refused` — `test/controllers/base/org/iam/grants_controller_test.rb:249`
- `Base::Org::Iam::GrantsControllerTest#test_the_grant_screen_asks_for_Step-Up_only_after_the_grant_capability_is_confirmed` — `test/controllers/base/org/iam/grants_controller_test.rb:284`
- `Base::Org::Organizations::MembershipsControllerTest#test_index_lists_the_bureau's_real_memberships` — `test/controllers/base/org/organizations/memberships_controller_test.rb:35`
- `Base::Org::Organizations::MembershipsControllerTest#test_org_idor_cannot_swap_membership_id_from_another_org` — `test/controllers/base/org/organizations/memberships_controller_test.rb:105`
- `Base::Org::Organizations::MembershipsControllerTest#test_show_returns_the_membership_the_actor_may_read` — `test/controllers/base/org/organizations/memberships_controller_test.rb:194`
- `Base::Org::Organizations::MembershipsControllerTest#test_unauthenticated_cannot_access_memberships` — `test/controllers/base/org/organizations/memberships_controller_test.rb:26`
- `Base::Org::OrganizationsControllerTest#test_index_renders` — `test/controllers/base/org/organizations_controller_test.rb:20`
- `Base::Org::OrganizationsControllerTest#test_show_rejects_organization_outside_the_current_operator_membership_set` — `test/controllers/base/org/organizations_controller_test.rb:39`
- `Base::Org::OrganizationsControllerTest#test_show_resolves_by_public_id` — `test/controllers/base/org/organizations_controller_test.rb:29`
- `Base::Org::OrganizationsControllerTest#test_unknown_public_id_returns_404` — `test/controllers/base/org/organizations_controller_test.rb:46`
- `Base::Org::StaffConsolePagesTest#test_audit_console_denies_an_operator_that_holds_no_grant` — `test/controllers/base/org/staff_console_pages_test.rb:98`
- `Base::Org::StaffConsolePagesTest#test_billing_console_denies_an_operator_that_holds_no_grant` — `test/controllers/base/org/staff_console_pages_test.rb:105`
- `Base::Org::StaffConsolePagesTest#test_iam_console_denies_an_operator_that_holds_no_grant` — `test/controllers/base/org/staff_console_pages_test.rb:111`
- `Base::Org::StaffConsolePagesTest#test_iam_console_opens_with_iam.capability.read` — `test/controllers/base/org/staff_console_pages_test.rb:174`
- `Base::Org::StaffConsolePagesTest#test_settings_console_denies_an_operator_that_holds_no_grant` — `test/controllers/base/org/staff_console_pages_test.rb:129`
- `Base::Org::StaffConsolePagesTest#test_support_console_denies_an_operator_that_holds_no_grant` — `test/controllers/base/org/staff_console_pages_test.rb:123`
- `Base::Org::StaffConsolePagesTest#test_support_console_opens_with_support.console.read_and_lists_only_granted_areas` — `test/controllers/base/org/staff_console_pages_test.rb:153`
- `Base::Org::StaffConsolePagesTest#test_system_console_denies_an_operator_that_holds_no_grant` — `test/controllers/base/org/staff_console_pages_test.rb:117`
- `Base::Org::StaffConsolePagesTest#test_the_dashboard_shows_Administration_only_for_consoles_the_operator_is_granted` — `test/controllers/base/org/staff_console_pages_test.rb:198`
- `Base::Org::Support::EnforcementApprovalFailuresTest#test_each_event_names_the_operator_who_performed_it:_A_opens,_B_approves_and_applies,_C_releases` — `test/controllers/base/org/support/enforcement_approval_failures_test.rb:322`
- `Base::Org::Support::EnforcementApprovalFailuresTest#test_failure_after_the_claim_but_before_the_apply_starts_releases_the_claim` — `test/controllers/base/org/support/enforcement_approval_failures_test.rb:204`
- `Base::Org::Support::EnforcementApprovalFailuresTest#test_failure_after_the_lock_took_effect_keeps_the_lock_and_the_approver,_and_reconciliation_writes_both_events` — `test/controllers/base/org/support/enforcement_approval_failures_test.rb:274`
- `Base::Org::Support::EnforcementApprovalFailuresTest#test_failure_before_the_claim:_a_case_that_is_not_pending_is_refused_and_left_unchanged` — `test/controllers/base/org/support/enforcement_approval_failures_test.rb:183`
- `Base::Org::Support::EnforcementApprovalFailuresTest#test_failure_in_the_lock_after_the_state_change_commits_keeps_the_Case_active_and_keeps_the_approver` — `test/controllers/base/org/support/enforcement_approval_failures_test.rb:256`
- `Base::Org::Support::EnforcementApprovalFailuresTest#test_failure_while_persisting_effects_rolls_the_apply_back_entirely_and_releases_the_claim` — `test/controllers/base/org/support/enforcement_approval_failures_test.rb:229`
- `Base::Org::Support::EnforcementCasesControllerTest#test_a_break-glass_request_on_create_is_refused_rather_than_trusted` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:580`
- `Base::Org::Support::EnforcementCasesControllerTest#test_a_case_naming_no_existing_principal_is_not_found` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:489`
- `Base::Org::Support::EnforcementCasesControllerTest#test_a_malformed_principal_filter_is_a_bad_request,_not_an_empty_list` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:1550`
- `Base::Org::Support::EnforcementCasesControllerTest#test_a_permanent_ban_is_not_released_through_the_console` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:1389`
- `Base::Org::Support::EnforcementCasesControllerTest#test_a_second_approval_of_the_same_case_is_a_conflict_and_does_not_apply_it_twice` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:858`
- `Base::Org::Support::EnforcementCasesControllerTest#test_a_second_operator_with_the_approve_capability_approves,_and_the_audit_event_names_them` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:761`
- `Base::Org::Support::EnforcementCasesControllerTest#test_a_separate_operator_with_the_review_capability_rejects_an_appeal,_and_the_event_names_them` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:1488`
- `Base::Org::Support::EnforcementCasesControllerTest#test_an_approver_named_in_the_create_request_is_ignored;_the_Case_waits_for_a_real_approval` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:667`
- `Base::Org::Support::EnforcementCasesControllerTest#test_an_unknown_release_reason_is_refused_instead_of_defaulting` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:1289`
- `Base::Org::Support::EnforcementCasesControllerTest#test_index_scopes_strictly_to_the_app_realm` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:1526`
- `Base::Org::Support::EnforcementCasesControllerTest#test_operator_with_apply_capability_and_Step-Up_opens_a_cooldown_case_that_applies_immediately` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:393`
- `Base::Org::Support::EnforcementCasesControllerTest#test_recent_Step-Up_evidence_is_reusable_for_a_different_protected_operation` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:304`
- `Base::Org::Support::EnforcementCasesControllerTest#test_releasing_one_blocking_case_keeps_the_principal_locked_while_another_blocking_case_is_in_force` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:1162`
- `Base::Org::Support::EnforcementCasesControllerTest#test_the_apply_capability_without_Step-Up_does_not_open_a_case` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:214`
- `Base::Org::Support::EnforcementCasesControllerTest#test_the_read_capability_lists_cases_without_Step-Up_but_does_not_allow_opening_one` — `test/controllers/base/org/support/enforcement_cases_controller_test.rb:133`
- `Base::Org::Support::SessionRevocationsTest#test_a_recorded_revocation_is_not_shown_under_a_different_target` — `test/controllers/base/org/support/session_revocations_test.rb:587`
- `Base::Org::Support::SessionRevocationsTest#test_a_session_created_after_the_revocation_is_untouched:_revocation_ends_what_existed,_it_does_not_lock` — `test/controllers/base/org/support/session_revocations_test.rb:316`
- `Base::Org::Support::SessionRevocationsTest#test_an_admin-locked_operator_loses_their_grants'_effect` — `test/controllers/base/org/support/session_revocations_test.rb:458`
- `Base::Org::Support::SessionRevocationsTest#test_an_operator_with_capability_and_Step-Up_revokes_a_client's_sessions_and_sees_the_recorded_result` — `test/controllers/base/org/support/session_revocations_test.rb:271`
- `Base::Org::Support::SessionRevocationsTest#test_if_the_audit_intent_cannot_be_written,_no_session_is_revoked` — `test/controllers/base/org/support/session_revocations_test.rb:523`
- `Base::Org::Support::SessionRevocationsTest#test_if_the_audit_result_cannot_be_written,_the_result_page_reports_the_operation_as_unconfirmed` — `test/controllers/base/org/support/session_revocations_test.rb:552`
- `Base::Org::Support::SessionRevocationsTest#test_page_boundary:_399_and_400_are_accepted,_empty_means_the_first_page` — `test/controllers/base/org/support/session_revocations_test.rb:190`
- `Base::Org::Support::SessionRevocationsTest#test_reason_codes,_ticket_ids,_and_operation_ids_outside_their_contract_are_refused_without_revoking` — `test/controllers/base/org/support/session_revocations_test.rb:390`
- `Base::Org::Support::SessionRevocationsTest#test_resubmitting_the_same_operation_requires_identical_request_metadata` — `test/controllers/base/org/support/session_revocations_test.rb:345`
- `Base::Org::Support::SessionRevocationsTest#test_search_and_page_inputs_outside_their_contract_are_bad_requests,_not_empty_lists` — `test/controllers/base/org/support/session_revocations_test.rb:152`
- `Base::Org::Support::SessionRevocationsTest#test_search_length_boundary:_63_and_64_characters_are_accepted` — `test/controllers/base/org/support/session_revocations_test.rb:171`
- `Base::Org::Support::SessionRevocationsTest#test_the_app_read_capability_lists_and_shows_clients_without_exposing_identifiers` — `test/controllers/base/org/support/session_revocations_test.rb:118`
- `Base::Org::Support::SessionRevocationsTest#test_ticket_id_length_boundary:_63_and_64_characters_are_accepted` — `test/controllers/base/org/support/session_revocations_test.rb:417`
- `Base::Org::Support::SessionRevocationsTest#test_with_the_revoke_capability_but_no_Step-Up,_the_screen_returns_an_authentication_challenge` — `test/controllers/base/org/support/session_revocations_test.rb:234`
- `Base::Org::Support::StandbyEnforcementCasesControllerTest#test_Standby_cannot_grant_or_revoke_capabilities_despite_fresh_matching_Step-Up` — `test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb:430`
- `Base::Org::Support::StandbyEnforcementCasesControllerTest#test_Standby_cannot_start_Step-Up_or_authenticator_bootstrap_from_Base` — `test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb:577`
- `BaseIdentityCredentialManagementTest#test_org_secret_credential_removal_discards_the_credential_when_another_remains` — `test/controllers/base/identity_credential_management_test.rb:168`
- `BaseIdentityReadOnlyPagesTest#test_app_standing_page_lists_an_in-force_decision_against_the_client` — `test/controllers/base/identity_read_only_pages_test.rb:488`
- `BaseIdentityReadOnlyPagesTest#test_app_standing_page_reports_the_signed-in_client's_account_standing` — `test/controllers/base/identity_read_only_pages_test.rb:95`
- `BaseIdentityReadOnlyPagesTest#test_org_activity_log_lists_the_operator's_own_recorded_activity` — `test/controllers/base/identity_read_only_pages_test.rb:300`
- `BaseIdentityReadOnlyPagesTest#test_org_standing_page_lists_an_in-force_decision_against_the_operator` — `test/controllers/base/identity_read_only_pages_test.rb:584`
- `BaseIdentityReadOnlyPagesTest#test_org_standing_page_reports_the_signed-in_operator's_account_standing` — `test/controllers/base/identity_read_only_pages_test.rb:120`
- `BaseIdentitySessionsPresentationTest#test_app_rejects_an_otherwise_valid_Access_Token_after_its_session_absolute_expiry` — `test/controllers/base/identity_sessions_presentation_test.rb:61`
- `BaseIdentitySessionsPresentationTest#test_app_session_inventory_contains_only_read-only_user-facing_fields` — `test/controllers/base/identity_sessions_presentation_test.rb:24`
- `BaseIdentitySessionsPresentationTest#test_app_session_inventory_links_to_its_own_GET_detail_with_complete_display_columns` — `test/controllers/base/identity_sessions_presentation_test.rb:40`
- `BaseIdentitySessionsPresentationTest#test_org_rejects_an_otherwise_valid_Access_Token_after_its_session_absolute_expiry` — `test/controllers/base/identity_sessions_presentation_test.rb:65`
- `BaseIdentitySessionsPresentationTest#test_org_session_inventory_contains_only_read-only_user-facing_fields` — `test/controllers/base/identity_sessions_presentation_test.rb:57`
- `BaseOrgIamOwnerApiTest#test_IAM_grant_and_revoke_commit_through_the_owner_boundary_and_preserve_the_API_response_shape` — `test/integration/base_org_iam_owner_api_test.rb:135`
- `BaseOrgIdentityOwnerEndpointsTest#test_an_unselected_ORG_root_reports_an_empty_tuple_without_creating_selection_state` — `test/controllers/base/org/api/v0/identity/owner_endpoints_test.rb:55`
- `BaseOrgIdentityOwnerEndpointsTest#test_client_assertions_cannot_be_reused_or_moved_to_another_owner_endpoint` — `test/controllers/base/org/api/v0/identity/owner_endpoints_test.rb:185`
- `BaseOrgIdentityOwnerEndpointsTest#test_selection_returns_only_the_authenticated_ORG_root_tuple_and_does_not_change_its_timestamp` — `test/controllers/base/org/api/v0/identity/owner_endpoints_test.rb:86`
- `BaseOrgIdentityOwnerEndpointsTest#test_standing_returns_a_good_account_page_scoped_to_the_verified_operator` — `test/controllers/base/org/api/v0/identity/owner_endpoints_test.rb:103`
- `BaseOrgIdentityOwnerEndpointsTest#test_standing_serializes_visible_timed_and_indefinite_decisions_but_excludes_another_operator's_decisions` — `test/controllers/base/org/api/v0/identity/owner_endpoints_test.rb:141`
- `BaseOrgIdentityRpRootFeatureRefusalTest#test_local_RP_session_receives_explicit_refusal_for_root_token_features` — `test/controllers/base/org/identity/rp_root_feature_refusal_test.rb:35`
- `BaseStepUpStartTest#test_Base_ORG_refuses_Auth-mediated_step-up_without_creating_state` — `test/integration/base_step_up_start_test.rb:87`
- `ClientSecretNameCommittedHttpTest#test_current_Step-Up_renames_the_Secret_and_commits_one_source_event_over_HTTP` — `test/integration/client_secret_name_committed_http_test.rb:63`
- `CspViolationReportIntakeTest#test_surface_is_derived_for_app_com_org_net_and_dev_hosts` — `test/services/csp_violation_report_intake_test.rb:220`
- `CspViolationReportsControllerTest#test_Base_CSP_intake_accepts_browser_reports_without_issuing_credentials` — `test/controllers/csp_violation_reports_controller_test.rb:41`
- `CsrfNotificationEmissionTest#test_a_blocked_request_is_recorded_once,_by_the_subscriber,_with_no_framework_CSRF_warning` — `test/integration/csrf_notification_emission_test.rb:105`
- `CsrfNotificationEmissionTest#test_a_cross-site_POST_is_blocked_and_emits_csrf_request_blocked_with_a_usable_payload` — `test/integration/csrf_notification_emission_test.rb:55`
- `CsrfNotificationEmissionTest#test_the_subscriber_records_a_blocked_request_without_logging_the_request_or_message` — `test/integration/csrf_notification_emission_test.rb:65`
- `DefaultNoStoreBaseTest#test_Base_app_ApplicationController_authentication_redirect_is_no-store` — `test/integration/default_no_store_base_test.rb:25`
- `DefaultNoStoreBaseTest#test_Base_org_ApplicationController_authentication_redirect_is_no-store` — `test/integration/default_no_store_base_test.rb:72`
- `EnforcementReconciliationJobTest#test_completes_the_end_audit_for_an_approved_appeal_whose_case_already_ended` — `test/jobs/enforcement_reconciliation_job_test.rb:326`
- `EnforcementReconciliationJobTest#test_ends_an_active_case_whose_approved_appeal_did_not_finish_ending_it` — `test/jobs/enforcement_reconciliation_job_test.rb:286`
- `FqdnAvailabilityGateTest#test_an_enabled_FQDN_serves_the_request` — `test/integration/fqdn_availability_gate_test.rb:52`
- `IdentityEmailCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering` — `test/services/identity/email_ceremony_contract_test.rb:71`
- `IdentitySecretCredentialCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering` — `test/services/identity/secret_credential_ceremony_contract_test.rb:84`
- `IdentitySettingsPageCoverageTest#test_operator_browses_identity_sessions_secrets_and_telephones` — `test/integration/identity_settings_page_coverage_test.rb:95`
- `IdentityStepUpCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_payload_tampering` — `test/services/identity/step_up_ceremony_contract_test.rb:143`
- `IdentityStepUpCeremonyTransactionPurgerTest#test_retires_an_expired_binding_before_deleting_it_and_its_parent` — `test/operations/identity_step_up_ceremony_transaction_purger_test.rb:98`
- `IdentityTelephoneCeremonyContractTest#test_signature_verification_rejects_wrong_key_tampered_payload_wrong_kid_and_wrong_issuer_audience` — `test/services/identity/telephone_ceremony_contract_test.rb:143`
- `IdentityTotpCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering` — `test/services/identity/totp_ceremony_contract_test.rb:73`
- `InertiaPageContractTest#test_a_page_with_no_validation_failure_still_carries_an_empty_errors_hash` — `test/integration/inertia_page_contract_test.rb:115`
- `InertiaPageContractTest#test_an_Inertia_visit_returns_the_page_object_as_JSON_with_the_same_current_page_url` — `test/integration/inertia_page_contract_test.rb:68`
- `InertiaPageContractTest#test_asset_version_is_identical_for_an_Inertia_page_served_on_another_surface_host` — `test/integration/inertia_page_contract_test.rb:219`
- `InertiaPageContractTest#test_history_is_encrypted_and_not_cleared_on_an_ordinary_page,_initial_and_Inertia_alike` — `test/integration/inertia_page_contract_test.rb:141`
- `InertiaPageContractTest#test_initial_page_script_carries_the_response_CSP_nonce` — `test/integration/inertia_page_contract_test.rb:101`
- `InertiaPageContractTest#test_initial_page_url_is_the_requested_path_including_the_query_string` — `test/integration/inertia_page_contract_test.rb:50`
- `InertiaPageContractTest#test_initial_response_carries_the_page_in_a_script_element_and_leaves_the_root_element_bare` — `test/integration/inertia_page_contract_test.rb:89`
- `InertiaPageContractTest#test_initial_response_embeds_the_full_page_object,_not_just_a_component_name` — `test/integration/inertia_page_contract_test.rb:30`
- `InertiaPageContractTest#test_page_url_keeps_a_percent-encoded_non-ASCII_query_value_unchanged` — `test/integration/inertia_page_contract_test.rb:199`
- `InertiaPageContractTest#test_page_url_keeps_several_query_parameters_and_stays_origin-relative` — `test/integration/inertia_page_contract_test.rb:181`
- `LayoutMetaTagsTest#test_inertia_layout_includes_lang_and_theme_markers` — `test/integration/layout_meta_tags_test.rb:55`
- `ObjectPlacementTest#test_every_file_names_its_own_role` — `test/tooling/object_placement_test.rb:148`
- `OpAuthorityStopConcurrencyTest#test_two_independent_requests_with_the_same_idempotency_key_commit_one_root_stop` — `test/concurrency/op_authority_stop_concurrency_test.rb:94`
- `OpAuthorityStopPurgerTest#test_a_stop_whose_participants_are_final_is_deleted_with_its_children_and_releases_the_root` — `test/operations/op_authority_stop_purger_test.rb:34`
- `OpAuthorityStopPurgerTest#test_an_all-roots_stop_stays_until_every_target_root_reaches_its_own_retention_deadline` — `test/operations/op_authority_stop_purger_test.rb:69`
- `OpIdentityEventSweepJobTest#test_a_same-sender_receipt_with_a_conflicting_event_type_is_reported_during_a_sweep` — `test/jobs/op_identity_event_sweep_job_test.rb:59`
- `OpenapiPreferencesContractTest#test_base_app_preference_endpoints_conform_to_the_app_description` — `test/contracts/openapi_preferences_contract_test.rb:48`
- `OpenapiPreferencesContractTest#test_base_org_preference_endpoints_conform_to_the_org_description` — `test/contracts/openapi_preferences_contract_test.rb:48`
- `OpenapiRouteCoverageTest#test_no_route_the_router_serves_is_missing_from_its_surface_description` — `test/contracts/openapi_route_coverage_test.rb:62`
- `OrgAdminStepUpCeremonyTest#test_Support_revocation_page_accepts_a_current_OP_event_installed_in_its_RP_session` — `test/integration/org_admin_step_up_ceremony_test.rb:68`
- `OrgAdminStepUpCeremonyTest#test_Support_revocation_requires_recent_proof_in_this_RP_session` — `test/integration/org_admin_step_up_ceremony_test.rb:52`
- `PreferenceOptionTamperingTest#test_timezone_update_accepts_a_numeric_option_id_given_as_a_string` — `test/integration/preference_option_tampering_test.rb:78`
- `PreferenceOptionTamperingTest#test_timezone_update_resolves_each_spelling_of_an_option_name_to_the_same_option` — `test/integration/preference_option_tampering_test.rb:54`
- `PreferenceReferenceDefaultsRecoveryTest#test_an_app_preference_write_restores_a_missing_audit_level_and_records_its_audit_entry` — `test/integration/preference_reference_defaults_recovery_test.rb:24`
- `PreferenceReferenceDefaultsRecoveryTest#test_an_org_preference_write_restores_a_missing_audit_level_on_the_audit_writer` — `test/integration/preference_reference_defaults_recovery_test.rb:38`
- `PreferenceWebCsrfTest#test_missing_Sec-Fetch-Site_legacy_fallback_passes_only_with_the_same_session-bound_token` — `test/integration/preference_web_csrf_test.rb:438`
- `PreferenceWebCsrfTest#test_ordinary_base_app_endpoint_rejects_a_foreign_origin_even_with_a_real_session-bound_token` — `test/integration/preference_web_csrf_test.rb:325`
- `PublicIdFixedLengthContractTest#test_every_PublicId_model's_own_test_asserts_the_fixed_public_id_length` — `test/models/public_id_fixed_length_contract_test.rb:35`
- `RecurringCeremonyCleanupContractTest#test_production_recurring_schedule_registers_all_ceremony_transaction_purge_jobs` — `test/jobs/recurring_ceremony_cleanup_contract_test.rb:23`
- `RiRoutingContractTest#test_set_region_is_skipped_only_in_the_reviewed_allowlist` — `test/unit/security/ri_routing_contract_test.rb:107`
- `Security::Invariants::OrgWithdrawalGateInvariantTest#test_a_closing_operator_on_the_Base_org_identity_surface_is_redirected_to_withdrawal` — `test/security/invariants/org_withdrawal_gate_invariant_test.rb:52`
- `Security::Invariants::ReadOnlyRouteWriteInvariantTest#test_ordinary_Base_GET_navigation_does_not_write_authentication_or_preference_state` — `test/security/invariants/read_only_route_write_invariant_test.rb:80`
- `StaffLifecycleBoundaryTest#test_org_withdrawal_route_is_informational_instead_of_destructive_self_service` — `test/integration/staff_lifecycle_boundary_test.rb:40`
- `StepUpCeremonyObservabilityTest#test_RP_step-up_start_logs_a_keyed_reference_without_state,_actor_or_session_identifiers` — `test/integration/step_up_ceremony_observability_test.rb:47`
- `StepUpRequiredResponseShapeTest#test_an_app_Inertia_request_receives_a_challenge_without_an_external-location_response` — `test/integration/step_up_required_response_shape_test.rb:220`
- `StepUpRequiredResponseShapeTest#test_an_app_JSON_request_from_a_client_with_no_step-up_method_asks_to_register_one` — `test/integration/step_up_required_response_shape_test.rb:472`
- `StepUpRequiredResponseShapeTest#test_an_authorized_app_document_request_receives_the_challenge_and_an_explicit_entry_link` — `test/integration/step_up_required_response_shape_test.rb:120`
- `StepUpRequiredResponseShapeTest#test_an_authorized_org_document_request_receives_the_challenge_and_an_explicit_entry_link` — `test/integration/step_up_required_response_shape_test.rb:298`
- `StepUpRequiredResponseShapeTest#test_an_org_scripted_request_receives_localized_plain_text_and_the_challenge` — `test/integration/step_up_required_response_shape_test.rb:394`
- `SurfaceRootLandingTest#test_base_app_root_with_an_unrecognized_region_renders_Home_without_redirect` — `test/controllers/surface_root_landing_test.rb:58`
- `SurfaceRootLandingTest#test_base_app_root_without_a_region_renders_Home_without_redirect` — `test/controllers/surface_root_landing_test.rb:17`
- `SurfaceSignOutEntryAndBirthdateTest#test_org_birthdate_page_shows_the_operator's_stored_birthdate_behind_a_fresh_step-up` — `test/controllers/surface_sign_out_entry_and_birthdate_test.rb:40`
- `Tech::Org::DashboardsControllerTest#test_an_operator_with_current_tech_access_sees_the_empty_protected_dashboard` — `test/controllers/tech/org/dashboards_controller_test.rb:57`
- `TechOrgAccessRevocationTest#test_a_committed_grant_revocation_refuses_the_next_protected_request` — `test/integration/tech_org_access_revocation_test.rb:48`
- `TechOrgAccessRevocationTest#test_a_grant_is_refused_before_its_start,_honoured_at_its_start_and_just_before_its_expiry,_refused_at_expiry` — `test/integration/tech_org_access_revocation_test.rb:40`
- `TechOrgAccessRevocationTest#test_an_unreadable_capability_store_returns_no_protected_content_and_reuses_no_earlier_result` — `test/integration/tech_org_access_revocation_test.rb:105`
- `TechOrgAccessRevocationTest#test_positive_control:_an_expired_access_credential_is_refreshed_while_the_grant_is_in_force` — `test/integration/tech_org_access_revocation_test.rb:61`
- `ViteAssetNonceTest#test_every_Vite_asset_tag_on_an_Inertia_page_carries_the_response_nonce` — `test/integration/vite_asset_nonce_test.rb:38`
- `WelcomeAndActivitySeamsTest#test_org_authenticated_welcome_offers_its_own_next_step` — `test/controllers/welcome_and_activity_seams_test.rb:38`
- `WithdrawalLifecycleSecurityTest#test_confirmed_withdrawal_revokes_all_normal_sessions_and_issues_a_ceremony_session` — `test/integration/withdrawal_lifecycle_security_test.rb:102`
- `Wua6StandbySupportRevocationScreenTest#test_ORG_read-only_owner_screens_deny_Standby_and_allow_Normal_with_fresh_matching_Step-Up` — `test/integration/wua6_standby_support_revocation_screen_test.rb:98`
## Final test error identifiers

Count: 48; exception-class counts: `ActiveRecord::RecordNotUnique`=22, `ArgumentError`=3, `AvatarOwnershipTransfers::InvalidTransfer`=4, `KeyError`=8, `NoMethodError`=2, `RuntimeError`=9.
- `ActiveRecord::RecordNotUnique` — `Base::Org::Identity::BirthdatesControllerTest#test_show_includes_the_stored_birthdate_when_one_is_present`
- `ActiveRecord::RecordNotUnique` — `Base::Org::Identity::BirthdatesControllerTest#test_show_reports_that_a_birthdate_is_not_set`
- `ActiveRecord::RecordNotUnique` — `Base::Org::Identity::BirthdatesControllerTest#test_standby_session_cannot_view_the_step-up_protected_birthdate`
- `ActiveRecord::RecordNotUnique` — `OpAuthorityStopCommitterTest#test_a_grant_stop_ends_only_that_grant_and_keeps_the_root_and_sibling_grants`
- `ActiveRecord::RecordNotUnique` — `OpAuthorityStopCommitterTest#test_a_principal_stop_records_its_cutoff_and_every_revoked_root;_zero_roots_is_a_recorded_stop`
- `ActiveRecord::RecordNotUnique` — `OpAuthorityStopCommitterTest#test_a_re-run_of_the_same_stop_returns_the_stored_stop_and_writes_nothing_again`
- `ActiveRecord::RecordNotUnique` — `OpAuthorityStopCommitterTest#test_a_root_stop_revokes_the_root_and_every_grant_and_records_targets`
- `ActiveRecord::RecordNotUnique` — `OpAuthorityStopCommitterTest#test_a_stop_without_an_established_principal_or_evidence_is_refused_before_any_write`
- `ActiveRecord::RecordNotUnique` — `OpAuthorityStopCommitterTest#test_an_already_revoked_root_is_not_stopped_again`
- `ActiveRecord::RecordNotUnique` — `OpAuthorityStopCommitterTest#test_an_app_root_stop_does_not_query_each_grant's_device_session_separately`
- `ActiveRecord::RecordNotUnique` — `OpAuthorityStopCommitterTest#test_an_org_root_stop_does_not_query_each_grant's_device_session_separately`
- `ActiveRecord::RecordNotUnique` — `OpAuthorityStopCommitterTest#test_cause_and_scope_must_match_the_accepted_authority-stop_matrix`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_browser_session_scope_locks_the_parent_before_any_RP_Session`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_browser_session_scope_rejects_a_record_that_is_not_a_Base_Browser_Session`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_browser_session_scope_revokes_an_operator_session's_RP_Sessions_and_the_operator_token`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_browser_session_scope_revokes_an_unrevoked_child_after_its_refresh_window_expires`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_browser_session_scope_revokes_every_active_child_for_the_parent`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_identity_scope_rejects_a_record_that_is_not_enumerable`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_identity_scope_walks_each_Base_Browser_Session`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_rejects_an_unsupported_revoke_scope`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_rp_session_scope_locks_the_parent_before_the_targeted_child`
- `ActiveRecord::RecordNotUnique` — `RpSessionRevokerTest#test_rp_session_scope_revokes_only_the_targeted_child`
- `ArgumentError` — `CredentialRegistrationOtpSessionValueTest#test_registration_session_encodes_the_original_Root_and_realm_channel_transaction_bound_browser_digest`
- `ArgumentError` — `Outbound::SmsDeliveryJobTest#test_retired_corporate_OTP_deliveries_are_reported_without_sending`
- `ArgumentError` — `OutboundSensitivePayloadTest#test_registration_OTP_SMS_uses_version_four_and_preserves_its_original_ceremony_tuple`
- `AvatarOwnershipTransfers::InvalidTransfer` — `AvatarRegistryTransferFailureTest#test_app_to_app_transfer_rolls_back_a_destination_write_failure_and_retries_once`
- `AvatarOwnershipTransfers::InvalidTransfer` — `AvatarRegistryTransferFailureTest#test_app_to_org_transfer_rolls_back_a_destination_write_failure_and_retries_once`
- `AvatarOwnershipTransfers::InvalidTransfer` — `AvatarRegistryTransferFailureTest#test_org_to_app_transfer_rolls_back_a_destination_write_failure_and_retries_once`
- `AvatarOwnershipTransfers::InvalidTransfer` — `AvatarRegistryTransferFailureTest#test_org_to_org_transfer_rolls_back_a_destination_write_failure_and_retries_once`
- `KeyError` — `Base::App::DashboardAvatarImagesControllerTest#test_answers_a_matching_If-None-Match_with_304_and_no_body`
- `KeyError` — `Base::Org::DashboardAvatarImagesControllerTest#test_switching_back_to_the_Avatar-less_selection_drops_the_previous_Avatar's_image`
- `KeyError` — `DefaultWebRateLimitTest#test_surface_base_enforces_the_300/min_default_web_limit_and_renders_the_json_429`
- `KeyError` — `OpAuthorityStopPurgerTest#test_a_stop_with_a_pending_participant_holds_its_root`
- `KeyError` — `Outbound::SmsProviders::AwsSnsTest#test_raises_ArgumentError_when_body_is_blank`
- `KeyError` — `Outbound::SmsProviders::AwsSnsTest#test_raises_ArgumentError_when_phone_number_is_blank`
- `KeyError` — `Outbound::SmsProviders::AwsSnsTest#test_sends_message_with_custom_subject`
- `KeyError` — `Outbound::SmsProviders::AwsSnsTest#test_sends_message_with_default_subject`
- `NoMethodError` — `Base::App::GroupsControllerTest#test_client_reorders_and_detaches_a_selected-account_membership`
- `NoMethodError` — `WithdrawalLifecycleSecurityTest#test_withdrawal_recovery_is_rejected_before_one_hour_and_after_purge_deadline`
- `RuntimeError` — `Base::App::DashboardAvatarImagesControllerTest#test_the_dashboard_points_a_stored-image-less_Avatar_at_the_default_version`
- `RuntimeError` — `Base::App::DashboardAvatarImagesControllerTest#test_the_image_cache_key_changes_with_the_Avatar,_so_another_Persona's_image_is_never_reused`
- `RuntimeError` — `Base::App::FullAccessGateTest#test_dashboard_renders_after_selector_persists_context`
- `RuntimeError` — `Base::App::Identity::WithdrawalsControllerTest#test_ending_the_withdrawal_ceremony_session_clears_Inertia_history_on_the_next_page`
- `RuntimeError` — `Base::Org::DashboardAvatarImagesControllerTest#test_a_selected_Avatar_with_a_stored_image_is_shown_and_streamed_privately`
- `RuntimeError` — `Base::Org::DashboardAvatarImagesControllerTest#test_a_selected_Avatar_without_a_stored_image_is_a_normal_absence_with_no_default_image`
- `RuntimeError` — `Base::Org::DashboardAvatarImagesControllerTest#test_no_selected_Avatar_is_a_normal_absence:_no_image_element_and_a_404_image`
- `RuntimeError` — `CrossSurfaceIsolationTest#test_client_is_authenticated_on_the_app_dashboard`
- `RuntimeError` — `CrossSurfaceIsolationTest#test_operator_is_authenticated_on_the_org_dashboard`
## Confirmed clean-HEAD pre-existing failure identifiers

The prior hard-reset evidence records these four account-controller failures and five identity-session failures on clean HEAD. Current run identifiers:

- `Base::App::AccountsControllerTest#test_index_lists_accounts` — `test/controllers/base/app/accounts_controller_test.rb:31`
- `Base::App::AccountsControllerTest#test_show_resolves_by_public_id` — `test/controllers/base/app/accounts_controller_test.rb:45`
- `Base::App::AccountsControllerTest#test_unknown_public_id_returns_404` — `test/controllers/base/app/accounts_controller_test.rb:71`
- `Base::App::AccountsControllerTest#test_show_rejects_account_outside_the_current_client_membership_set` — `test/controllers/base/app/accounts_controller_test.rb:63`
- `BaseIdentitySessionsPresentationTest#test_app_session_inventory_links_to_its_own_GET_detail_with_complete_display_columns` — `test/controllers/base/identity_sessions_presentation_test.rb:40`
- `BaseIdentitySessionsPresentationTest#test_app_rejects_an_otherwise_valid_Access_Token_after_its_session_absolute_expiry` — `test/controllers/base/identity_sessions_presentation_test.rb:61`
- `BaseIdentitySessionsPresentationTest#test_app_session_inventory_contains_only_read-only_user-facing_fields` — `test/controllers/base/identity_sessions_presentation_test.rb:24`
- `BaseIdentitySessionsPresentationTest#test_org_session_inventory_contains_only_read-only_user-facing_fields` — `test/controllers/base/identity_sessions_presentation_test.rb:57`
- `BaseIdentitySessionsPresentationTest#test_org_rejects_an_otherwise_valid_Access_Token_after_its_session_absolute_expiry` — `test/controllers/base/identity_sessions_presentation_test.rb:65`

## Historical failure identifier changes after structure restoration (before Jump test repair)
The pre-restore run had 9,857 runs, 228 failures and 1,157 errors. The earlier post-restore run had 9,857 runs, 247 failures and 49 errors. Restoring the schema snapshots removed the FK error family and let additional tests reach behavioral assertions. Relative to the pre-restore failure-ID set, 23 failure IDs were newly surfaced and 4 no longer fail. This set comparison does not attribute those surfaced behavior failures to the route cleanup.
### Newly surfaced test failure identifiers
- `Base::App::AccountsControllerTest#test_index_lists_accounts`
- `IdentityTotpCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering`
- `PreferenceReferenceDefaultsRecoveryTest#test_an_app_preference_write_restores_a_missing_audit_level_and_records_its_audit_entry`
- `Base::App::Identity::WithdrawalsControllerTest#test_update_without_acknowledging_the_purge_schedule_leaves_the_client_active`
- `Base::Org::AccountsControllerTest#test_unknown_public_id_returns_404`
- `Base::Org::AccountsControllerTest#test_show_resolves_by_public_id`
- `Base::App::Verification::SetupsControllerTest#test_authenticator_bootstrap_choices_refuse_before_writing_an_admission`
- `Base::App::Verification::SetupsControllerTest#test_the_protected_operation_of_an_actor_without_an_authenticator_leads_to_the_Base_method_choice`
- `BaseIdentitySessionsPresentationTest#test_app_session_inventory_contains_only_read-only_user-facing_fields`
- `BaseIdentitySessionsPresentationTest#test_org_rejects_an_otherwise_valid_Access_Token_after_its_session_absolute_expiry`
- `Base::Org::StaffConsolePagesTest#test_iam_console_opens_with_iam.capability.read`
- `PublicIdFixedLengthContractTest#test_every_PublicId_model's_own_test_asserts_the_fixed_public_id_length`
- `OpAuthorityStopConcurrencyTest#test_two_independent_requests_with_the_same_idempotency_key_commit_one_root_stop`
- `Base::Org::Iam::GrantPagesTest#test_an_unknown_grant_public_id_is_not_found`
- `Base::App::BillingsControllerTest#test_index_renders_for_signed_in_clients`
- `ActorSupportLifecycleTest#test_action_policy_receives_current_actor_context_for_authenticated_app_request`
- `InertiaPageContractTest#test_initial_response_embeds_the_full_page_object,_not_just_a_component_name`
- `Base::App::DashboardAvatarImagesControllerTest#test_a_storage_failure_surfaces_as_an_error_instead_of_the_default_image`
- `InertiaPageContractTest#test_initial_page_url_is_the_requested_path_including_the_query_string`
- `PreferenceOptionTamperingTest#test_timezone_update_accepts_a_numeric_option_id_given_as_a_string`
- `Base::App::OrganizationsControllerTest#test_unknown_public_id_returns_404`
- `Base::App::OrganizationsControllerTest#test_show_resolves_by_public_id`
- `BaseIdentityReadOnlyPagesTest#test_org_standing_page_reports_the_signed-in_operator's_account_standing`

### No longer failing identifiers
- `I18nRuntimeDefaultCleanupTest#test_runtime_default_cleanup_keys_exist_for_ja_and_en`
- `DatabaseReconstructionAuthorityTest#test_primary_uses_the_conventional_db/structure.sql_dump_path`
- `DatabaseReconstructionAuthorityTest#test_committed_structure_dumps_contain_real_table_definitions`
- `DatabaseReconstructionAuthorityTest#test_publishing_reconstructs_from_migrations_rather_than_publishing_structure.sql`
