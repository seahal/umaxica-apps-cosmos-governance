# Governance route separation cleanup evidence

- Date: 2026-11-09.
- HEAD: `43db4906742db2fb13b238c9ccde378e4e1583b4`.
- The worktree was already dirty. Results include the current uncommitted work; no commit was made and unrelated changes were preserved.
- Baseline: [2026-11-09-governance-route-separation-baseline-G7Q2.md](2026-11-09-governance-route-separation-baseline-G7Q2.md), 17,164 runs, 301 failures, 72 errors, 373 listed IDs.
- Test commands used `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=test` to run against the connected test databases. No `.env*` file was read.

## Changes in this cleanup

- Removed the Warp-only `BrowserRpParentStateFailClosedTest`; its requests targeted a surface no longer drawn by this app.
- Narrowed retained route inventories and host matrices to Base/Tech: regional roots, retired sign-out paths, legacy health paths, static GET coverage, and MCP withdrawal checks.
- Removed Auth/Visa-only retired route cases; retargeted the corporate social-boundary and anonymous preference tests to Base com.
- Retargeted shared Browser RP concern coverage from the removed Core client to Base app. Its local-session cases remain pending the explicitly deferred Base App local-cell work.
- Narrowed the preference OpenAPI contract to Base app/org/com and removed stale external content-route exceptions from route parameter guards.
- No application route, controller, authorization, CSRF or persistence implementation was changed in this cleanup.

## Verification

- `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=test bin/rails test test/security`: exit 1; (126, 752, 3, 0, 0).
- `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`: exit 1; (14486, 108955, 132, 24, 0).
- `UMAXICA_ENV_FILE=/dev/null bin/rubocop`: 4,692 files inspected, no offenses.
- `UMAXICA_ENV_FILE=/dev/null bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: exit 0, 0 warnings, 0 errors.
- `git diff --check`: clean.

## Baseline comparison

- Current full-suite result IDs: 156 total (132 failures, 24 errors).
- 133 current IDs match the baseline (109 failures, 24 errors); 23 are new failure IDs; there are 0 new errors.
- The reduction from 17,164 to 14,486 runs includes deletion of tests scoped only to surfaces outside Governance and other pre-existing working-tree changes. It is not presented as a test pass-rate comparison.
- Every current failure/error is grouped below by kind, exception class, and first repository line. Baseline-matched IDs remain listed in the pre-work baseline artifact.

### Current failures and errors by first repository line

| Kind | Exception | First repository line | Current | Baseline match | New |
|---|---|---|---:|---:|---:|
| Error | `ActiveRecord::RecordNotFound` | `app/models/client_sign_up_flow.rb:183` | 1 | 1 | 0 |
| Error | `ActiveRecord::RecordNotUnique` | `app/models/concerns/public_id.rb:57` | 1 | 1 | 0 |
| Error | `ArgumentError` | `app/controllers/concerns/actor_support.rb:123` | 2 | 2 | 0 |
| Error | `ArgumentError` | `app/models/email_otp_verification_failure_budget.rb:39` | 1 | 1 | 0 |
| Error | `ArgumentError` | `app/operations/authentication_other_sessions_revoker.rb:20` | 1 | 1 | 0 |
| Error | `ArgumentError` | `app/operations/enforcement_case_end_operation.rb:166` | 1 | 1 | 0 |
| Error | `ArgumentError` | `app/operations/oidc_authorization_code_issuer.rb:92` | 1 | 1 | 0 |
| Error | `ArgumentError` | `app/operations/rp_step_up_callback_dispatcher.rb:393` | 1 | 1 | 0 |
| Error | `ArgumentError` | `app/values/credential_registration_otp_session_value.rb:10` | 1 | 1 | 0 |
| Error | `ArgumentError` | `app/values/telephone_credential_registration_otp_delivery_binding_value.rb:17` | 2 | 2 | 0 |
| Error | `ArgumentError` | `test/support/rp_cell_session_helper.rb:132` | 3 | 3 | 0 |
| Error | `AvatarOwnershipTransfers::InvalidTransfer` | `app/operations/avatar_ownership_transfers/operation.rb:16` | 4 | 4 | 0 |
| Error | `EmailSignUpOtpDeliveryIssuer::DeliveryUnavailable` | `app/operations/email_sign_up_otp_delivery_issuer.rb:27` | 1 | 1 | 0 |
| Error | `IdentityTotpNameCommitter::DependencyFailure` | `app/operations/identity_totp_name_committer.rb:93` | 1 | 1 | 0 |
| Error | `NoMethodError` | `test/controllers/base/welcome_return_target_realms_test.rb:120` | 1 | 1 | 0 |
| Error | `NoMethodError` | `test/integration/withdrawal_lifecycle_security_test.rb:448` | 1 | 1 | 0 |
| Error | `TelephoneSignUpOtpDeliveryIssuer::DeliveryUnavailable` | `app/operations/telephone_sign_up_otp_delivery_issuer.rb:26` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/contracts/openapi_preferences_contract_test.rb:48` | 2 | 2 | 0 |
| Failure | `Minitest::Assertion` | `test/contracts/openapi_route_coverage_test.rb:63` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/api/v0/preferences/theme_controller_test.rb:146` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/billings_controller_test.rb:73` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/identity/withdrawals_controller_test.rb:103` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/identity/withdrawals_controller_test.rb:111` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/identity/withdrawals_controller_test.rb:119` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/identity/withdrawals_controller_test.rb:129` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/identity/withdrawals_controller_test.rb:173` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/identity/withdrawals_controller_test.rb:96` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/identity_authority_slice_1a_test.rb:33` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/rp_root_feature_refusal_test.rb:94` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/verification/setups_controller_test.rb:108` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/verification/setups_controller_test.rb:136` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/verification/setups_controller_test.rb:156` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/verification/setups_controller_test.rb:170` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/verification/setups_controller_test.rb:192` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/verification/setups_controller_test.rb:215` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/verification/setups_controller_test.rb:225` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/verification/setups_controller_test.rb:256` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/app/verification/setups_controller_test.rb:264` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_credential_management_test.rb:168` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_read_only_pages_test.rb:167` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_read_only_pages_test.rb:267` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_read_only_pages_test.rb:378` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_read_only_pages_test.rb:473` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_read_only_pages_test.rb:568` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_read_only_pages_test.rb:657` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_read_only_pages_test.rb:88` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_sessions_presentation_test.rb:24` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_sessions_presentation_test.rb:41` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_sessions_presentation_test.rb:58` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_sessions_presentation_test.rb:62` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/identity_sessions_presentation_test.rb:66` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/oidc_result_csrf_transport_test.rb:37` | 2 | 2 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grant_submissions_test.rb:117` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grant_submissions_test.rb:225` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grant_submissions_test.rb:336` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grant_submissions_test.rb:433` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grants_controller_test.rb:223` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grants_controller_test.rb:335` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grants_controller_test.rb:436` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grants_controller_test.rb:555` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grants_controller_test.rb:709` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grants_controller_test.rb:804` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/iam/grants_controller_test.rb:979` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/identity/rp_root_feature_refusal_test.rb:76` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/staff_console_pages_test.rb:153` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/staff_console_pages_test.rb:174` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/staff_console_pages_test.rb:198` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/enforcement_cases_controller_test.rb:1804` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/enforcement_cases_controller_test.rb:2323` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/session_revocations_test.rb:1106` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/session_revocations_test.rb:1211` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/session_revocations_test.rb:1332` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/session_revocations_test.rb:1435` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/session_revocations_test.rb:1547` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/session_revocations_test.rb:1654` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/session_revocations_test.rb:1762` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/session_revocations_test.rb:1870` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/session_revocations_test.rb:914` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb:580` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/org/welcome_dashboard_authority_slice_1c_test.rb:772` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/welcome_return_target_realms_test.rb:146` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/base/welcome_return_target_realms_test.rb:95` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/auth/base_test.rb:577` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/authenticated_response_cache_policy_test.rb:582` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/browser_rp_authentication_test.rb:1007` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/browser_rp_authentication_test.rb:180` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/browser_rp_authentication_test.rb:202` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/browser_rp_authentication_test.rb:298` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/browser_rp_authentication_test.rb:535` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/browser_rp_authentication_test.rb:788` | 3 | 0 | 3 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/browser_rp_authentication_test.rb:962` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/concerns/sign/org_verification_base_included_do_test.rb:116` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/csp_violation_reports_controller_test.rb:41` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/controllers/surface_root_landing_test.rb:17` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/surface_root_landing_test.rb:58` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/surface_sign_out_entry_and_birthdate_test.rb:92` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/controllers/welcome_and_activity_seams_test.rb:39` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/acceptance_wu02_base_rp_state_test.rb:55` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/anonymous_com_web_push_initialization_test.rb:578` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/integration/anonymous_com_web_push_initialization_test.rb:609` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/integration/app_secret_login_journey_test.rb:101` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/base_dashboard_authentication_guidance_test.rb:105` | 2 | 2 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/client_secret_name_committed_http_test.rb:63` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/email_delivery_test.rb:48` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/integration/identity_settings_page_coverage_test.rb:164` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/oidc_rp_logout_edit_return_test.rb:82` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/integration/oidc_rp_logout_registered_rp_matrix_test.rb:131` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/oidc_rp_logout_registered_rp_matrix_test.rb:40` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/preference_option_tampering_test.rb:54` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/preference_option_tampering_test.rb:78` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/preference_reference_defaults_recovery_test.rb:24` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/preference_reference_defaults_recovery_test.rb:38` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/preference_web_csrf_test.rb:326` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/preference_web_csrf_test.rb:439` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/routes/neutral_rp_entry_contract_test.rb:89` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/rp_cell_local_session_readiness_test.rb:54` | 2 | 0 | 2 |
| Failure | `Minitest::Assertion` | `test/integration/staff_lifecycle_boundary_test.rb:101` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/step_up_authentication_test.rb:221` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/step_up_required_response_shape_test.rb:120` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/step_up_required_response_shape_test.rb:218` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/step_up_required_response_shape_test.rb:298` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/step_up_required_response_shape_test.rb:394` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/step_up_required_response_shape_test.rb:472` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/tech_org_access_revocation_test.rb:61` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/integration/tech_org_access_revocation_test.rb:74` | 1 | 0 | 1 |
| Failure | `Minitest::Assertion` | `test/integration/withdrawal_lifecycle_security_test.rb:238` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/wua6_standby_support_revocation_screen_test.rb:146` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/integration/xper_retired_hosts_test.rb:58` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/jobs/enforcement_reconciliation_job_test.rb:286` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/jobs/enforcement_reconciliation_job_test.rb:326` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/operations/identity_step_up_totp_device_concurrency_test.rb:181` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/security/invariants/org_withdrawal_gate_invariant_test.rb:52` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/security/invariants/withdrawal_gate_invariant_test.rb:35` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/security/invariants/withdrawal_gate_invariant_test.rb:67` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/services/identity/email_ceremony_contract_test.rb:88` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/services/identity/passkey_ceremony_contract_test.rb:88` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/services/identity/secret_credential_ceremony_contract_test.rb:107` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/services/identity/social_ceremony_contract_test.rb:318` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/services/identity/step_up_ceremony_contract_test.rb:181` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/services/identity/telephone_ceremony_contract_test.rb:160` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/services/identity/totp_ceremony_contract_test.rb:90` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/tooling/object_placement_test.rb:148` | 1 | 1 | 0 |
| Failure | `Minitest::Assertion` | `test/unit/core/surface_test.rb:44` | 1 | 1 | 0 |

### New failure IDs and cause classification

#### Retained Base/Tech or operational behavior outside removed-route references; left unchanged

- `AnonymousComWebPushInitializationTest#test_the_read-only_corporate_host_displays_a_valid_shared_JWT_without_preference_DB_or_private_key` — `Minitest::Assertion`, `test/integration/anonymous_com_web_push_initialization_test.rb:609`.
- `AnonymousComWebPushInitializationTest#test_the_read-only_corporate_host_does_not_clear_invalid_shared_preference_cookies_or_read_preference_rows` — `Minitest::Assertion`, `test/integration/anonymous_com_web_push_initialization_test.rb:578`.
- `BaseIdentitySessionsPresentationTest#test_app_session_inventory_contains_only_read-only_user-facing_fields` — `Minitest::Assertion`, `test/controllers/base/identity_sessions_presentation_test.rb:24`.
- `BaseIdentitySessionsPresentationTest#test_org_session_inventory_contains_only_read-only_user-facing_fields` — `Minitest::Assertion`, `test/controllers/base/identity_sessions_presentation_test.rb:58`.
- `BaseOrgIdentityRpRootFeatureRefusalTest#test_local_RP_session_receives_explicit_refusal_for_root_token_features` — `Minitest::Assertion`, `test/controllers/base/org/identity/rp_root_feature_refusal_test.rb:76`.
- `CspViolationReportsControllerTest#test_Base_CSP_intake_accepts_browser_reports_without_issuing_credentials` — `Minitest::Assertion`, `test/controllers/csp_violation_reports_controller_test.rb:41`.
- `EmailDeliveryTest#test_deliver_later_enqueues_a_job_in_solid_queue` — `Minitest::Assertion`, `test/integration/email_delivery_test.rb:48`.
- `RpCellLocalSessionReadinessTest#test_base-org-ww_signs_out_locally_before_revoking_its_Refresh_Token` — `Minitest::Assertion`, `test/integration/rp_cell_local_session_readiness_test.rb:54`.
- `TechOrgAccessRevocationTest#test_a_request_that_must_refresh_its_credentials_after_a_grant_revocation_is_refused_and_loses_its_cookies` — `Minitest::Assertion`, `test/integration/tech_org_access_revocation_test.rb:74`.
- `TechOrgAccessRevocationTest#test_positive_control:_an_expired_access_credential_is_refreshed_while_the_grant_is_in_force` — `Minitest::Assertion`, `test/integration/tech_org_access_revocation_test.rb:61`.

#### Base App local-cell follow-up (explicitly deferred to the next work unit)

- `BrowserRpAuthenticationTest#test_a_refresh_credential_"0"_of_1_bytes_is_decided_by_the_authority` — `Minitest::Assertion`, `test/controllers/concerns/browser_rp_authentication_test.rb:788`.
- `BrowserRpAuthenticationTest#test_a_refresh_credential_"aaaaaaaaaaaa"_of_4000_bytes_is_decided_by_the_authority` — `Minitest::Assertion`, `test/controllers/concerns/browser_rp_authentication_test.rb:788`.
- `BrowserRpAuthenticationTest#test_a_refresh_credential_"malformed"_of_9_bytes_is_decided_by_the_authority` — `Minitest::Assertion`, `test/controllers/concerns/browser_rp_authentication_test.rb:788`.
- `BrowserRpAuthenticationTest#test_a_safe_request_cannot_refresh_credentials_after_its_parent_Browser_Session_is_revoked` — `Minitest::Assertion`, `test/controllers/concerns/browser_rp_authentication_test.rb:535`.
- `BrowserRpAuthenticationTest#test_an_expired_access_cookie_refreshes_independently_and_replaces_both_RP_cookies` — `Minitest::Assertion`, `test/controllers/concerns/browser_rp_authentication_test.rb:180`.
- `BrowserRpAuthenticationTest#test_an_invalid_refresh_clears_RP_cookies_and_leaves_a_protected_request_unauthenticated` — `Minitest::Assertion`, `test/controllers/concerns/browser_rp_authentication_test.rb:202`.
- `BrowserRpAuthenticationTest#test_an_unsafe_request_whose_refresh_is_refused_performs_no_mutation` — `Minitest::Assertion`, `test/controllers/concerns/browser_rp_authentication_test.rb:1007`.
- `BrowserRpAuthenticationTest#test_an_unsafe_request_with_an_expired_access_credential_refreshes_once_and_performs_one_mutation` — `Minitest::Assertion`, `test/controllers/concerns/browser_rp_authentication_test.rb:962`.
- `BrowserRpAuthenticationTest#test_invalid_RP_credentials_log_presence_without_either_credential_value` — `Minitest::Assertion`, `test/controllers/concerns/browser_rp_authentication_test.rb:298`.
- `RpCellLocalSessionReadinessTest#test_base-app-ww_signs_out_locally_before_revoking_its_Refresh_Token` — `Minitest::Assertion`, `test/integration/rp_cell_local_session_readiness_test.rb:54`.

#### Renamed/retargeted Base-to-Access/Visa behavior; related behavior already failed in the baseline

- `Base::App::Verification::SetupsControllerTest#test_choosing_the_authenticator_app_starts_a_TOTP-only_bootstrap_and_redirects_to_Access` — `Minitest::Assertion`, `test/controllers/base/app/verification/setups_controller_test.rb:225`.
- `Base::App::Verification::SetupsControllerTest#test_email_bootstrap_sends_the_admitted_transaction_to_Access` — `Minitest::Assertion`, `test/controllers/base/app/verification/setups_controller_test.rb:264`.
- `OidcRpLogoutEditReturnTest#test_Base_ORG_self-RP_returns_to_Base_staff_after_Visa_logout` — `Minitest::Assertion`, `test/integration/oidc_rp_logout_edit_return_test.rb:82`.

### Security-suite failures

- The security suite has 3 failures and 0 errors. All three IDs are listed in the baseline artifact; they were left unchanged as instructed.
- `Security::Invariants::WithdrawalGateInvariantTest#test_withdrawal_allowlist_route_remains_reachable` — `Minitest::Assertion`, `test/security/invariants/withdrawal_gate_invariant_test.rb:67`.
- `Security::Invariants::WithdrawalGateInvariantTest#test_closing_resource_is_redirected_away_from_protected_html_routes` — `Minitest::Assertion`, `test/security/invariants/withdrawal_gate_invariant_test.rb:35`.
- `Security::Invariants::OrgWithdrawalGateInvariantTest#test_a_closing_operator_on_the_Base_org_identity_surface_is_redirected_to_withdrawal` — `Minitest::Assertion`, `test/security/invariants/org_withdrawal_gate_invariant_test.rb:52`.

## Acceptance status

- Separation-caused full-suite errors: 0.
- `bin/rails test test/security` failure count is not zero because its 3 failures predate this work. The instruction to leave baseline failures untouched conflicts with the zero-failure security acceptance condition.
- New failure IDs are classified above. The Base App local-cell work remains the stated next work unit; no local-cell migration was attempted here.
- No commit was made.
