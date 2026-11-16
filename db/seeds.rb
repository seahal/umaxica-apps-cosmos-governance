# typed: false
# frozen_string_literal: true

# Reference data (lookup / status tables) is normally owned by migrations, which insert the fixed
# rows with `INSERT ... ON CONFLICT DO NOTHING` (see adr/reference-table-discipline.md). This file
# also replays fixed reference catalogs after a schema-only load, because migration markers
# suppress the original data inserts. The remaining content is development/test sample data.

[
  [PersonaMembershipKind, PersonaMembershipState, PersonaMembershipRevokeReason,
   AgentMembershipKind, AgentMembershipState, AgentMembershipRevokeReason,
   OperatorEntraIdentityState, OrganizationEntraConnectionState,
   ClientChronicleEvent, ClientChronicleLevel, OperatorChronicleEvent, OperatorChronicleLevel,],
  [AvatarMembershipStatus, AvatarOwnershipStatus, AvatarPermission, AvatarRole, HandleStatus, HandleAssignmentStatus,
   DepartmentStatus, DivisionStatus, OperatorWorkspaceAccountStatus, OrganizationStatus,],
  [ComPreferenceStatus, ComPreferenceChronicleEvent, ComPreferenceChronicleLevel,
   ComPreferenceLanguageOption, ComPreferenceRegionOption, ComPreferenceThemeOption, ComPreferenceTimezoneOption,
   ComPreferenceCurrencyOption, ComPreferenceDateFormatOption, ComPreferenceDensityOption, ComPreferenceMotionOption,
   ComPreferencePageSizeOption, ComPreferenceTimeFormatOption, ComPreferenceWebPushOption,],
  [AppPreferenceLanguageOption, AppPreferenceRegionOption, AppPreferenceThemeOption, AppPreferenceTimezoneOption,
   AppPreferenceCurrencyOption, AppPreferenceDateFormatOption, AppPreferenceDensityOption, AppPreferenceMotionOption,
   AppPreferencePageSizeOption, AppPreferenceTimeFormatOption,],
  [OrgPreferenceLanguageOption, OrgPreferenceRegionOption, OrgPreferenceThemeOption, OrgPreferenceTimezoneOption,
   OrgPreferenceCurrencyOption, OrgPreferenceDateFormatOption, OrgPreferenceDensityOption, OrgPreferenceMotionOption,
   OrgPreferencePageSizeOption, OrgPreferenceTimeFormatOption,],
  [ClientPreferenceLanguageOption, ClientPreferenceRegionOption, ClientPreferenceThemeOption,
   ClientPreferenceTimezoneOption, ClientPreferenceCurrencyOption, ClientPreferenceDateFormatOption,
   ClientPreferenceDensityOption, ClientPreferenceMotionOption, ClientPreferencePageSizeOption,
   ClientPreferenceTimeFormatOption,],
  [OperatorPreferenceLanguageOption, OperatorPreferenceRegionOption, OperatorPreferenceThemeOption,
   OperatorPreferenceTimezoneOption, OperatorPreferenceCurrencyOption, OperatorPreferenceDateFormatOption,
   OperatorPreferenceDensityOption, OperatorPreferenceMotionOption, OperatorPreferencePageSizeOption,
   OperatorPreferenceTimeFormatOption,],
  [ClientStatus, ClientVisibility, ClientSecurityMode, ClientMfaStatus, ClientEmailStatus,
   ClientTelephoneStatus, ClientPasskeyStatus, ClientTotpCredentialStatus, ClientIdentityState,
   OperatorStatus, OperatorVisibility, OperatorSecurityMode, OperatorMfaStatus, OperatorEmailStatus,
   OperatorTelephoneStatus, OperatorSecretCredentialKind, OperatorIdentityState,],
].flatten.each do |model|
  connection = model.lease_connection
  table = connection.quote_table_name(model.table_name)
  model::DEFAULTS.each do |id|
    connection.execute("INSERT INTO #{table} (id) VALUES (#{connection.quote(id)}) ON CONFLICT (id) DO NOTHING")
  end
end

member_status_connection = MemberStatus.lease_connection
member_status_table = member_status_connection.quote_table_name(MemberStatus.table_name)
MemberStatus::DEFAULTS.each do |id|
  member_status_connection.execute(
    "INSERT INTO #{member_status_table} (id, created_at, updated_at) " \
    "VALUES (#{member_status_connection.quote(id)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT (id) DO NOTHING",
  )
end

[
  [OperatorPasskeyStatus, [OperatorPasskeyStatus::ACTIVE, OperatorPasskeyStatus::REVOKED]],
  [OperatorSecretCredentialStatus,
   [OperatorSecretCredentialStatus::ACTIVE, OperatorSecretCredentialStatus::DELETED,
    OperatorSecretCredentialStatus::EXPIRED, OperatorSecretCredentialStatus::REVOKED,
    OperatorSecretCredentialStatus::USED,],],
].each do |model, ids|
  connection = model.lease_connection
  table = connection.quote_table_name(model.table_name)
  ids.each do |id|
    connection.execute("INSERT INTO #{table} (id) VALUES (#{connection.quote(id)}) ON CONFLICT (id) DO NOTHING")
  end
end

return if Rails.env.production?

# Occurrence reference rows are owned by the occurrence database, not primary.
# A structure.sql load marks data migrations as applied without replaying their
# INSERTs, so reproduce the current JWT anomaly catalog through the same
# idempotent migration writer on the correct writer connection. During the
# pre-migration bootstrap both tables are absent and this section is skipped;
# a partially-created occurrence schema fails loudly instead of reporting a
# successful but incomplete seed.
occurrence_connection = OccurrenceRecord.lease_connection
occurrence_tables = %w(jwt_occurrence_statuses jwt_occurrences)
occurrence_table_presence =
  occurrence_tables.map do |table_name|
    occurrence_connection.data_source_exists?(table_name)
  end

if occurrence_table_presence.any?
  require Rails.root.join(
    "db/occurrences_migrate/20260918150000_insert_current_jwt_anomaly_reference_data",
  ).to_s
  InsertCurrentJwtAnomalyReferenceData.new.seed_into(occurrence_connection)
end

# Avatar lifecycle states are owned by the avatar database and are required by
# avatar provisioning (social sign-up completion). Replay them for the same
# structure.sql reason as the occurrence catalog above.
avatar_connection = AvatarRecord.lease_connection
if avatar_connection.data_source_exists?("avatar_lifecycle_states")
  require Rails.root.join(
    "db/avatars_migrate/20260703000001_create_avatar_lifecycle_state_authority",
  ).to_s
  CreateAvatarLifecycleStateAuthority.new.seed_into(avatar_connection)
end

sample_staff_public_id = "2222222222222222"
sample_staff_secret = "22222222222222222222222222222222"
sample_staff_email_address = "sample-staff@example.test"

user = Client.find_or_initialize_by(public_id: "sample_userxxxxxxxxxx")
user.status_id = ClientStatus::ACTIVE
user.visibility_id = ClientVisibility::USER
user.security_mode_id = ClientSecurityMode::NORMAL
user.mfa_status_id = ClientMfaStatus::UNCONFIGURED
user.save!

# `address` is encrypted, so a plaintext `find_or_initialize_by(address:)` never matches an
# existing row and the second seed run fails the blind-index uniqueness validation. Look the
# record up through the `with_address` scope, which searches the blind index instead.
sample_user_email_address = "sample-user@example.test"
user_email = user.client_emails.with_address(sample_user_email_address).first ||
  user.client_emails.new(address: sample_user_email_address)
user_email.user_email_status_id = ClientEmailStatus::VERIFIED
user_email.confirm_policy = true
user_email.save!

staff = Operator.find_or_initialize_by(public_id: sample_staff_public_id)
staff.status_id = OperatorStatus::ACTIVE
staff.visibility_id = OperatorVisibility::USER
staff.security_mode_id = OperatorSecurityMode::ADVANCED
staff.mfa_status_id = OperatorMfaStatus::UNCONFIGURED
staff.save!

staff_email = OperatorEmail.with_address(sample_staff_email_address).first ||
  OperatorEmail.new(address: sample_staff_email_address)
staff_email.staff = staff
staff_email.staff_email_status_id = OperatorEmailStatus::VERIFIED
staff_email.save!

staff_secret = staff.operator_secret_credentials.find_or_initialize_by(name: "sample-staff-secret")
staff_secret.staff_secret_kind_id = OperatorSecretCredentialKind::LOGIN
staff_secret.staff_identity_secret_status_id = OperatorSecretCredentialStatus::ACTIVE
staff_secret.password = sample_staff_secret
staff_secret.save!

# `fqdn_available_*` carries the same `:availability` polarity, so an unwritten flag closes the
# FQDN: a fresh primary database answers every request with 503 `fqdn_unavailable` before routing.
# Every slot the router serves is opened here so a freshly seeded development environment serves the
# hosts its own routes declare. Production is untouched (this file returns above) -- switching a
# public FQDN on stays an explicit operator decision made through the Flipper UI.
FqdnAvailabilityRegistry.flag_names.each { |feature_name| Flipper.enable(feature_name) }
