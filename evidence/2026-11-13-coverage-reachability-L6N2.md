# Public/protected reachability audit

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree was already heavily modified. `git status --short` reported 1,011 paths before
this evidence file was created. This audit describes the combined current worktree; unrelated paths
were preserved. No commit, push, deployment, CI change, credential change, database schema change,
or database data mutation was made.

## Changes in this continuation

- Removed six protected `track_authenticated_session_activity?` overrides from the APP and ORG root,
  preferences, and dashboard-avatar-image controllers. Repository searches found no callback
  registration or caller; runtime inspection showed no superclass implementation for any of the six,
  so each `super` call would fail if invoked. Current code also has no `touch_session_activity!`
  implementation.
- Removed the unused `SurfaceRouteAliasHelper` and its includes from Base APP, Base ORG, and Tech
  ORG. Source searches found no helper use of the mapped `auth_*`, `sign_*`, or `acme_*` prefixes.
  `Rails.application.routes.named_routes` contains 239 `base_*` route helpers and none of those
  alias prefixes.
- Updated current lifecycle and DB-write documentation to state the current request path. No
  database, credential, route definition, or user-visible behavior changed.

## Verification

| Check                                                                                                  | Result                                                                                                                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| APP/ORG root, preferences, avatar-image and Base preference request tests before alias-helper removal  | 45 tests, 247 assertions, 0 failures/errors/skips                                                                                                                                                                                                                     |
| Route-contract, APP/ORG root, avatar-image and Tech dashboard request tests after alias-helper removal | 49 tests, 458 assertions, 0 failures/errors/skips                                                                                                                                                                                                                     |
| Full coverage-enabled Rails suite                                                                      | 7,499 tests, 50,191 assertions, 0 failures/errors/skips. Process exited 2 solely because the unchanged SimpleCov minimums were not met: line 90.37% (30,135/33,343; minimum 98%), branch 62.01% (3,501/5,645; minimum 93%), method 85.62% (4,353/5,084; minimum 97%). |
| `bin/rubocop`                                                                                          | Passed: 2,816 files, no offenses                                                                                                                                                                                                                                      |
| `bundle exec erb_lint --lint-all`                                                                      | Passed: 1,510 files, no errors                                                                                                                                                                                                                                        |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                       | Passed: 0 warnings, 0 errors                                                                                                                                                                                                                                          |
| `bun run check`                                                                                        | Passed; existing Knip hint reports compiled `.css` is excluded                                                                                                                                                                                                        |
| `RAILS_ENV=test bin/rails zeitwerk:check`                                                              | Passed: all is good                                                                                                                                                                                                                                                   |
| `RAILS_ENV=test bin/rails routes`                                                                      | Passed; no old route-alias prefixes found                                                                                                                                                                                                                             |
| `git diff --check`                                                                                     | Passed                                                                                                                                                                                                                                                                |

The Vitest coverage run recorded in [P7V4](2026-11-13-coverage-completion-P7V4.md) passed 59 files /
588 tests with 100% statements, branches, functions and lines. No JavaScript or TypeScript files
changed in this continuation. The test command used only the explicit test-writer database catalog;
no production, shared or external database was prepared or changed.

## Current public/protected method inventory

The runtime inventory contains 2,590 rows under `app/` and `lib/`. The 17 raw parallel SimpleCov
method tables were joined by source location using the installed
`SimpleCov::Combine::MethodsCombiner`.

| Classification                                  |  Rows |
| ----------------------------------------------- | ----: |
| Exact method hit                                | 2,297 |
| Uncovered source methods                        |   137 |
| No one-to-one method coverage location          |   135 |
| Same source line as another instrumented method |    21 |
| Total                                           | 2,590 |

The six unused activity overrides and the alias helper accounted for seven rows removed from the
prior inventory. The 135 no-location entries are generated accessors from `Data.define`, `Struct`,
Rails attribute APIs and `attr_reader`; there is no independent method body for SimpleCov to
instrument. The 21 same-line entries are aliases or generated attribute aliases sharing the source
body with the listed instrumented method. Their source forms are listed below rather than
force-called.

The 137 uncovered methods are fully listed below. Current route-backed actions are blocked before
their action body by the explicit unavailable Access authority boundary; the boundary tests assert
503/problem+json, `no-store`, and no redirect. This includes 69 APP/ORG API action methods and 23
secret/identity/verification actions that depend on Access-owned OP state. The 52 method/path
request pairs in `test/integration/base_access_authority_api_unavailable_test.rb`, together with the
existing membership, IAM, RP-root refusal, dashboard-identity, and verification boundary tests,
exercise the fail-closed entrypoints. These tests do not execute the post-Access success bodies and
no authentication or API result was mocked to make them pass.

Other uncovered methods fall into these current dispositions:

- `BrowserRpAuthentication` abstract hooks and owner-selection error helpers (5): abstract
  declarations or methods whose current callsites require the absent owner API. No current path can
  return a valid owner selection.
- `VerificationBase` step-up/verification methods (5): current controllers require Access-owned
  session or evidence state; those flows remain unavailable. No test-only controller was added.
- `Tech::Org::DashboardsController#show` (1): the real authenticated request test verifies explicit
  503 at the Access owner-policy boundary before the action.
- `ClientContactAuditOutbox.record_preferences_changed!` (1): no current application caller. The
  event writer remains, but the current tree has no preference-change committer that can supply the
  method's authenticated actor and same-transaction contract. Prior XDB-03 evidence describes an
  earlier caller; this current-tree discrepancy remains a follow-up.
- `RpPrincipal#policy_class` (1): no current `authorize!` call resolves a local RP principal through
  this hook.
- Six generated Core bridge `class_attribute` predicate accessors (6): the model tests exercise the
  actual configured getters through record creation; these generated `?` accessors have no callers
  or custom method bodies.
- `OperatorTelephonePublicIdBackfillOperation.call` (1): reached only from explicit maintenance Rake
  tasks. Current schema enforces a non-NULL identity; the legacy NULL repair state cannot be created
  under the current schema. The checklist links a test file that is absent from the current test
  tree; this documentation/test inventory mismatch remains open.
- `OrgIamOwnerMutationOperation.grant/revoke` (2): called only after the owner API action passes its
  Access authentication boundary; current requests return explicit 503 before invocation.
- `Acme::AccountQuotaPolicy#exceeded?` / `#remaining` and `Acme::OrganizationQuotaPolicy#exceeded?`
  / `#remaining` (4): no current product caller.
- `ApplicationPolicy#organization`, `#jwt_subject`, `#operator?`, `#operator_or_manager?`,
  `#can_edit?`, `#can_view?`, `#can_contribute?` (7): current policies do not call these legacy role
  helpers. They were retained because deleting authorization vocabulary is a separate security
  decision; no test called the protected methods directly.
- `AccountStandingResolver.call` (1): its only controller caller is blocked by the unavailable
  Access identity endpoint.
- `ClientSecretLifetimesValue.issuance_ttl/proof_retention` (2): called from secret-management paths
  and collection work that fail closed while Access-owned OP state is unavailable.
- `OidcClientRegistry.authenticate` (1): no current application caller; current client-auth requests
  use `authenticate_assertion`.
- `ArchitectureBaseline.write` (1): explicit repository-maintenance Rake task only; it writes the
  tracked RuboCop baseline and is not executed in the Rails behavior suite.
- `CredentialDeletionFinalizer.register` (1): no application caller exists although the current
  accepted invalid-credential ADR describes registration before exception responses. The middleware
  is mounted, but the registration contract is not wired in this tree. This security-contract
  discrepancy is recorded, not hidden by a synthetic test.
- `JitSecurityJwtJwksService.normalized_public_jwk` (1): no current caller; the active JWKS endpoint
  returns the registry-owned key set.
- `JitSecurityTurnstileConfig.stealth_site_key` (1): no current caller; credential/configuration
  construction is not exercised by Minitest.
- `Umaxica::TestEnvironment::DatabaseSafety.report` (1): test-host/environment safety report only;
  environment construction is executed outside Minitest per repository rule.
- `Umaxica::Valkey::ResponsibilityUrls.require_url`, `Umaxica::Valkey::Settings#performance`, and
  `#[]` (3): configuration/environment construction and diagnostics; no synthetic Minitest
  environment construction was added.

### Uncovered source methods (137)

- `app/controllers/base/app/api/v0/avatar/avatar_ownership_transfers_controller.rb`:
  Base::App::Api::V0::Avatar::AvatarOwnershipTransfersController#create,
  Base::App::Api::V0::Avatar::AvatarOwnershipTransfersController#accept,
  Base::App::Api::V0::Avatar::AvatarOwnershipTransfersController#cancel
- `app/controllers/base/app/api/v0/avatar/avatars_controller.rb`:
  Base::App::Api::V0::Avatar::AvatarsController#index,
  Base::App::Api::V0::Avatar::AvatarsController#show,
  Base::App::Api::V0::Avatar::AvatarsController#create,
  Base::App::Api::V0::Avatar::AvatarsController#update
- `app/controllers/base/app/api/v0/avatar/dashboard_identities_controller.rb`:
  Base::App::Api::V0::Avatar::DashboardIdentitiesController#show
- `app/controllers/base/app/api/v0/avatar/group_avatar_memberships_controller.rb`:
  Base::App::Api::V0::Avatar::GroupAvatarMembershipsController#create,
  Base::App::Api::V0::Avatar::GroupAvatarMembershipsController#update,
  Base::App::Api::V0::Avatar::GroupAvatarMembershipsController#destroy
- `app/controllers/base/app/api/v0/avatar/groups_controller.rb`:
  Base::App::Api::V0::Avatar::GroupsController#index,
  Base::App::Api::V0::Avatar::GroupsController#show,
  Base::App::Api::V0::Avatar::GroupsController#create,
  Base::App::Api::V0::Avatar::GroupsController#update,
  Base::App::Api::V0::Avatar::GroupsController#destroy
- `app/controllers/base/app/api/v0/avatar/selected_images_controller.rb`:
  Base::App::Api::V0::Avatar::SelectedImagesController#show
- `app/controllers/base/app/api/v0/avatar/social_edges_controller.rb`:
  Base::App::Api::V0::Avatar::SocialEdgesController#create,
  Base::App::Api::V0::Avatar::SocialEdgesController#destroy
- `app/controllers/base/app/api/v0/avatar/switchers_controller.rb`:
  Base::App::Api::V0::Avatar::SwitchersController#show,
  Base::App::Api::V0::Avatar::SwitchersController#update
- `app/controllers/base/app/api/v0/identity/selections_controller.rb`:
  Base::App::Api::V0::Identity::SelectionsController#show
- `app/controllers/base/app/api/v0/identity/standings_controller.rb`:
  Base::App::Api::V0::Identity::StandingsController#show
- `app/controllers/base/app/api/v0/membership/directory_controller.rb`:
  Base::App::Api::V0::Membership::DirectoryController#accounts,
  Base::App::Api::V0::Membership::DirectoryController#account,
  Base::App::Api::V0::Membership::DirectoryController#organizations,
  Base::App::Api::V0::Membership::DirectoryController#organization,
  Base::App::Api::V0::Membership::DirectoryController#memberships,
  Base::App::Api::V0::Membership::DirectoryController#membership,
  Base::App::Api::V0::Membership::DirectoryController#authorization
- `app/controllers/base/app/secret_issuances_controller.rb`:
  Base::App::SecretIssuancesController#show, Base::App::SecretIssuancesController#update,
  Base::App::SecretIssuancesController#destroy, Base::App::SecretIssuancesController#reattempt
- `app/controllers/base/app/secret_presentations_controller.rb`:
  Base::App::SecretPresentationsController#create
- `app/controllers/base/app/secrets_controller.rb`: Base::App::SecretsController#index,
  Base::App::SecretsController#show, Base::App::SecretsController#new,
  Base::App::SecretsController#edit, Base::App::SecretsController#create,
  Base::App::SecretsController#update, Base::App::SecretsController#destroy
- `app/controllers/base/org/api/v0/avatar/avatar_ownership_transfers_controller.rb`:
  Base::Org::Api::V0::Avatar::AvatarOwnershipTransfersController#create,
  Base::Org::Api::V0::Avatar::AvatarOwnershipTransfersController#accept,
  Base::Org::Api::V0::Avatar::AvatarOwnershipTransfersController#cancel
- `app/controllers/base/org/api/v0/avatar/dashboard_identities_controller.rb`:
  Base::Org::Api::V0::Avatar::DashboardIdentitiesController#show
- `app/controllers/base/org/api/v0/avatar/selected_avatars_controller.rb`:
  Base::Org::Api::V0::Avatar::SelectedAvatarsController#show,
  Base::Org::Api::V0::Avatar::SelectedAvatarsController#update,
  Base::Org::Api::V0::Avatar::SelectedAvatarsController#destroy
- `app/controllers/base/org/api/v0/avatar/selected_images_controller.rb`:
  Base::Org::Api::V0::Avatar::SelectedImagesController#show
- `app/controllers/base/org/api/v0/avatar/switchers_controller.rb`:
  Base::Org::Api::V0::Avatar::SwitchersController#show,
  Base::Org::Api::V0::Avatar::SwitchersController#update
- `app/controllers/base/org/api/v0/iam/grants_controller.rb`:
  Base::Org::Api::V0::Iam::GrantsController#index, Base::Org::Api::V0::Iam::GrantsController#show,
  Base::Org::Api::V0::Iam::GrantsController#screen,
  Base::Org::Api::V0::Iam::GrantsController#create, Base::Org::Api::V0::Iam::GrantsController#revoke
- `app/controllers/base/org/api/v0/identity/selections_controller.rb`:
  Base::Org::Api::V0::Identity::SelectionsController#show
- `app/controllers/base/org/api/v0/identity/standings_controller.rb`:
  Base::Org::Api::V0::Identity::StandingsController#show
- `app/controllers/base/org/api/v0/membership/directory_controller.rb`:
  Base::Org::Api::V0::Membership::DirectoryController#accounts,
  Base::Org::Api::V0::Membership::DirectoryController#account,
  Base::Org::Api::V0::Membership::DirectoryController#organizations,
  Base::Org::Api::V0::Membership::DirectoryController#organization,
  Base::Org::Api::V0::Membership::DirectoryController#memberships,
  Base::Org::Api::V0::Membership::DirectoryController#membership,
  Base::Org::Api::V0::Membership::DirectoryController#authorization
- `app/controllers/base/org/api/v0/support/accounts_controller.rb`:
  Base::Org::Api::V0::Support::AccountsController#index,
  Base::Org::Api::V0::Support::AccountsController#show,
  Base::Org::Api::V0::Support::AccountsController#revocation_screen,
  Base::Org::Api::V0::Support::AccountsController#revoke,
  Base::Org::Api::V0::Support::AccountsController#revocation
- `app/controllers/base/org/api/v0/support/areas_controller.rb`:
  Base::Org::Api::V0::Support::AreasController#index
- `app/controllers/base/org/api/v0/support/enforcement_cases/appeal_reviews_controller.rb`:
  Base::Org::Api::V0::Support::EnforcementCases::AppealReviewsController#new
- `app/controllers/base/org/api/v0/support/enforcement_cases/approvals_controller.rb`:
  Base::Org::Api::V0::Support::EnforcementCases::ApprovalsController#new,
  Base::Org::Api::V0::Support::EnforcementCases::ApprovalsController#create
- `app/controllers/base/org/api/v0/support/enforcement_cases/releases_controller.rb`:
  Base::Org::Api::V0::Support::EnforcementCases::ReleasesController#new,
  Base::Org::Api::V0::Support::EnforcementCases::ReleasesController#create
- `app/controllers/base/org/api/v0/support/enforcement_cases_controller.rb`:
  Base::Org::Api::V0::Support::EnforcementCasesController#index,
  Base::Org::Api::V0::Support::EnforcementCasesController#show,
  Base::Org::Api::V0::Support::EnforcementCasesController#new,
  Base::Org::Api::V0::Support::EnforcementCasesController#create
- `app/controllers/base/org/identity/removals_controller.rb`:
  Base::Org::Identity::RemovalsController#create
- `app/controllers/base/org/identity/secret_credentials_controller.rb`:
  Base::Org::Identity::SecretCredentialsController#index,
  Base::Org::Identity::SecretCredentialsController#show,
  Base::Org::Identity::SecretCredentialsController#new,
  Base::Org::Identity::SecretCredentialsController#edit,
  Base::Org::Identity::SecretCredentialsController#create,
  Base::Org::Identity::SecretCredentialsController#destroy
- `app/controllers/base/org/verification/cancellations_controller.rb`:
  Base::Org::Verification::CancellationsController#show,
  Base::Org::Verification::CancellationsController#create
- `app/controllers/base/org/verification/completions_controller.rb`:
  Base::Org::Verification::CompletionsController#show,
  Base::Org::Verification::CompletionsController#create
- `app/controllers/concerns/browser_rp_authentication.rb`:
  BrowserRpAuthentication#browser_rp_client_id, BrowserRpAuthentication#browser_rp_resource_type,
  BrowserRpAuthentication#token_class, BrowserRpAuthentication#selected_context_from_owner,
  BrowserRpAuthentication#render_rp_owner_dependency_failure!
- `app/controllers/concerns/verification_base.rb`: VerificationBase#verification_scope,
  VerificationBase#step_up_satisfied?, VerificationBase#require_step_up_unless_bootstrap!,
  VerificationBase#step_up_requirement, VerificationBase#step_up_satisfied_with_requirement?
- `app/controllers/tech/org/dashboards_controller.rb`: Tech::Org::DashboardsController#show
- `app/models/client_contact_audit_outbox.rb`: ClientContactAuditOutbox.record_preferences_changed!
- `app/models/concerns/rp_principal.rb`: RpPrincipal#policy_class
- `app/models/core_app_client_bridge.rb`: CoreAppClientBridge.core_default_client_id?,
  CoreAppClientBridge.core_default_audience?, CoreAppClientBridge.core_default_host?
- `app/models/core_org_operator_bridge.rb`: CoreOrgOperatorBridge.core_default_client_id?,
  CoreOrgOperatorBridge.core_default_audience?, CoreOrgOperatorBridge.core_default_host?
- `app/operations/operator_telephone_public_id_backfill_operation.rb`:
  OperatorTelephonePublicIdBackfillOperation.call
- `app/operations/org_iam_owner_mutation_operation.rb`: OrgIamOwnerMutationOperation.grant,
  OrgIamOwnerMutationOperation.revoke
- `app/policies/acme/account_quota_policy.rb`: Acme::AccountQuotaPolicy#exceeded?,
  Acme::AccountQuotaPolicy#remaining
- `app/policies/acme/organization_quota_policy.rb`: Acme::OrganizationQuotaPolicy#exceeded?,
  Acme::OrganizationQuotaPolicy#remaining
- `app/policies/application_policy.rb`: ApplicationPolicy#organization,
  ApplicationPolicy#jwt_subject, ApplicationPolicy#operator?,
  ApplicationPolicy#operator_or_manager?, ApplicationPolicy#can_edit?, ApplicationPolicy#can_view?,
  ApplicationPolicy#can_contribute?
- `app/resolvers/account_standing_resolver.rb`: AccountStandingResolver.call
- `app/values/client_secret_lifetimes_value.rb`: ClientSecretLifetimesValue.issuance_ttl,
  ClientSecretLifetimesValue.proof_retention
- `app/values/oidc_client_registry.rb`: OidcClientRegistry.authenticate
- `lib/architecture_baseline.rb`: ArchitectureBaseline.write
- `lib/credential_deletion_finalizer.rb`: CredentialDeletionFinalizer.register
- `lib/jit_security_jwt_jwks_service.rb`: JitSecurityJwtJwksService.normalized_public_jwk
- `lib/jit_security_turnstile_config.rb`: JitSecurityTurnstileConfig.stealth_site_key
- `lib/umaxica/test_environment/database_safety.rb`: Umaxica::TestEnvironment::DatabaseSafety.report
- `lib/umaxica/valkey/responsibility_urls.rb`: Umaxica::Valkey::ResponsibilityUrls.require_url
- `lib/umaxica/valkey/settings.rb`: Umaxica::Valkey::Settings#performance,
  Umaxica::Valkey::Settings#[]

### Methods with no one-to-one coverage location (135)

- `app/controllers/concerns/org_support_session_revocation_page.rb`:
  OrgSupportSessionRevocationPage::InvalidRevocationInput#errors
- `app/errors/application_error.rb`: ApplicationError#context, ApplicationError#i18n_key,
  ApplicationError#status_code
- `app/errors/blank_public_identifier_error.rb`: BlankPublicIdentifierError#record_class
- `app/errors/invalid_user_status_error.rb`: InvalidUserStatusError#invalid_status
- `app/forms/sign/app/settings/withdrawal/deactivate_form.rb`:
  Sign::App::Settings::Withdrawal::DeactivateForm#ack_deactivate_today,
  Sign::App::Settings::Withdrawal::DeactivateForm#ack_deactivate_today=
- `app/forms/sign/app/settings/withdrawal/schedule_form.rb`:
  Sign::App::Settings::Withdrawal::ScheduleForm#ack_schedule_purge,
  Sign::App::Settings::Withdrawal::ScheduleForm#ack_schedule_purge=
- `app/models/actor/authentication.rb`: Actor::Authentication#access_claims,
  Actor::Authentication#acr, Actor::Authentication#actor_id, Actor::Authentication#actor_type,
  Actor::Authentication#amr, Actor::Authentication#login_public_id
- `app/models/actor/preference.rb`: Actor::Preference#currency, Actor::Preference#date_format,
  Actor::Preference#density, Actor::Preference#language, Actor::Preference#motion,
  Actor::Preference#page_size, Actor::Preference#region, Actor::Preference#theme,
  Actor::Preference#time_format, Actor::Preference#timezone, Actor::Preference#web_push
- `app/models/actor/selected_context.rb`: Actor::SelectedContext#account_public_id,
  Actor::SelectedContext#avatar_public_id, Actor::SelectedContext#collective_public_id,
  Actor::SelectedContext#collective_unit_public_id, Actor::SelectedContext#selected_at
- `app/models/client_enforcement_recovery_ceremony.rb`:
  ClientEnforcementRecoveryCeremony#plaintext_token
- `app/models/client_totp_credential.rb`: ClientTotpCredential#first_token,
  ClientTotpCredential#first_token=
- `app/models/client_withdrawal_ceremony.rb`: ClientWithdrawalCeremony#plaintext_token
- `app/models/com_preference.rb`: ComPreference#confirm_reset, ComPreference#confirm_reset=
- `app/models/concerns/email.rb`: Email#confirm_policy, Email#confirm_policy=, Email#pass_code,
  Email#pass_code=, Email#raw_address=
- `app/models/concerns/telephone.rb`: Telephone#confirm_policy, Telephone#confirm_policy=,
  Telephone#confirm_using_mfa, Telephone#confirm_using_mfa=, Telephone#pass_code,
  Telephone#pass_code=, Telephone#raw_number=
- `app/models/operator_lifecycle_request.rb`: OperatorLifecycleRequest#target_operator_public_id,
  OperatorLifecycleRequest#target_operator_public_id=
- `app/models/operator_secret_credential.rb`: OperatorSecretCredential#raw_secret_credential,
  OperatorSecretCredential#raw_secret_credential=
- `app/operations/authority_owner_family_backfill_operation.rb`:
  AuthorityOwnerFamilyBackfillOperation::BackfillRejected#reason,
  AuthorityOwnerFamilyBackfillOperation::BackfillRejected#results
- `app/operations/authority_owner_family_cutover_operation.rb`:
  AuthorityOwnerFamilyCutoverOperation::CutoverRejected#reason
- `app/operations/authority_owner_predeployment_backfill_operation.rb`:
  AuthorityOwnerPredeploymentBackfillOperation::BackfillRejected#reason
- `app/operations/rp_step_up_start_issuer.rb`: RpStepUpStartIssuer::Refused#reason_code
- `app/services/avatar_lifecycle.rb`: AvatarLifecycle::Transition#avatar,
  AvatarLifecycle::Transition#changed_by_public_id, AvatarLifecycle::Transition#changed_by_type,
  AvatarLifecycle::Transition#metadata, AvatarLifecycle::Transition#reason,
  AvatarLifecycle::Transition#to_state_key
- `app/services/avatar_social_graph.rb`: AvatarSocialGraph::Follow#actor_avatar,
  AvatarSocialGraph::Follow#target_avatar, AvatarSocialGraph::Block#actor_avatar,
  AvatarSocialGraph::Block#target_avatar, AvatarSocialGraph::Mute#actor_avatar,
  AvatarSocialGraph::Mute#target_avatar, AvatarSocialGraph::Unfollow#actor_avatar,
  AvatarSocialGraph::Unfollow#target_avatar, AvatarSocialGraph::Unblock#actor_avatar,
  AvatarSocialGraph::Unblock#target_avatar, AvatarSocialGraph::Unmute#actor_avatar,
  AvatarSocialGraph::Unmute#target_avatar
- `app/services/health.rb`: Health::CheckResult#check, Health::CheckResult#dependencies,
  Health::CheckResult#generated_at, Health::CheckResult#revision, Health::CheckResult#status,
  Health::CheckResult#surface, Health::DependencyResult#kind, Health::DependencyResult#message,
  Health::DependencyResult#status, Health::Profiles::Base#cache_key,
  Health::Profiles::Base#record_classes, Health::Profiles::Base#status_policy,
  Health::Profiles::Base#surface_label
- `app/values/account_standing.rb`: AccountStanding#decisions, AccountStanding#level
- `app/values/authentication_context_value.rb`: AuthenticationContextValue#capabilities,
  AuthenticationContextValue#key
- `app/values/client_secret_issuance_count_value.rb`: ClientSecretIssuanceCountValue#active_count,
  ClientSecretIssuanceCountValue#reserved_count
- `app/values/oidc_client_assertion_step_up_expectation_value.rb`:
  OidcClientAssertionStepUpExpectationValue#grant, OidcClientAssertionStepUpExpectationValue#subject
- `app/values/preference_display_value.rb`: PreferenceDisplayValue#experience,
  PreferenceDisplayValue#language, PreferenceDisplayValue#preferences
- `app/values/problem_type.rb`: ProblemType#slug, ProblemType#status, ProblemType#title
- `app/values/processor_erasure_retry_policy.rb`: ProcessorErasureRetryPolicy#max_attempts,
  ProcessorErasureRetryPolicy#retry_delay_seconds
- `app/values/sign_risk_event.rb`: SignRiskEvent#name, SignRiskEvent#occurred_at,
  SignRiskEvent#payload
- `app/values/step_up_requirement.rb`: StepUpRequirement#actor_ref,
  StepUpRequirement#allowed_methods, StepUpRequirement#audience,
  StepUpRequirement#full_reauthentication_required, StepUpRequirement#phishing_resistant_required,
  StepUpRequirement#purpose, StepUpRequirement#require_session_binding,
  StepUpRequirement#required_aal, StepUpRequirement#resource_ref, StepUpRequirement#scope,
  StepUpRequirement#session_binding, StepUpRequirement#step_up_required,
  StepUpRequirement#tenant_ref, StepUpRequirement#token_binding, StepUpRequirement#ttl,
  StepUpRequirement#user_verification_required
- `app/values/umaxica/withdrawal/timing_policy_value.rb`:
  Umaxica::Withdrawal::TimingPolicyValue#early_termination_delay,
  Umaxica::Withdrawal::TimingPolicyValue#recovery_delay,
  Umaxica::Withdrawal::TimingPolicyValue#retention_period
- `app/values/url_search_params_value.rb`: UrlSearchParamsValue#pairs
- `app/values/webauthn/surface.rb`: Webauthn::Surface#actor_foreign_key,
  Webauthn::Surface#passkey_class_name, Webauthn::Surface#passkey_status_class_name
- `lib/umaxica/valkey/connection.rb`: Umaxica::Valkey::Connection#namespace,
  Umaxica::Valkey::Connection#url
- `lib/umaxica/valkey/settings.rb`: Umaxica::Valkey::Settings#rails_env

### Methods sharing an instrumented source line (21)

- `app/controllers/concerns/sign_error_responses.rb`: SignErrorResponses#staff_not_authorized,
  SignErrorResponses#user_not_authorized
- `app/models/actor.rb`: Actor.signed_in?, Actor.actor
- `app/models/actor/authentication.rb`: Actor::Authentication#eql?
- `app/models/actor/configuration.rb`: Actor::Configuration::NullValue#eql?,
  Actor::Configuration#eql?
- `app/models/actor/preference.rb`: Actor::Preference#eql?
- `app/models/actor/selected_context.rb`: Actor::SelectedContext#eql?
- `app/models/client_secret_credential.rb`: ClientSecretCredential#claim_ceremony_session_id=,
  ClientSecretCredential#claim_operation_id=, ClientSecretCredential#claim_sign_in_flow_ref=,
  ClientSecretCredential#claimed_at=, ClientSecretCredential#confirmed_at=,
  ClientSecretCredential#consumed_at=
- `app/models/client_secret_issuance.rb`: ClientSecretIssuance#confirmed_at=,
  ClientSecretIssuance#presented_at=, ClientSecretIssuance#signup_completed_at=
- `app/policies/client_chronicle_policy.rb`: ClientChroniclePolicy#show?
- `app/policies/operator_chronicle_policy.rb`: OperatorChroniclePolicy#show?
- `app/values/problem_type.rb`: ProblemType#eql?

## Acceptance status and remaining limits

- Vitest coverage remains at 100% for all four reported metrics.
- All Rails tests passed; the SimpleCov line, branch and method gates remain below their configured
  minimums, so the full command exits 2.
- Current public/protected source rows have caller/reachability dispositions, including the
  generated and alias mapping rows above. The blocked Access-owned success bodies are not claimed as
  covered.
- The accepted credential-deletion registration contract and the current-tree preference-change
  audit caller discrepancy remain unresolved design/implementation findings. They were not changed
  in this coverage slice.
- The pre-existing DatabaseConsistency finding remains separately recorded: one checker warning for
  `OperatorChronicle` and its valid conditional unique index. No DatabaseConsistency configuration
  or schema change was made here.
