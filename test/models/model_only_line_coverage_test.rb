# typed: false
# frozen_string_literal: true

require "test_helper"

class ModelOnlyLineCoverageTest < ActiveSupport::TestCase
  test "actor configuration null values and dynamic access preserve value semantics" do
    null_value = Actor::Configuration::NULL_VALUE
    configuration = Actor::Configuration.new(feature: "enabled")
    same = Actor::Configuration.new(feature: "enabled")

    assert_withheld { null_value.nil? }
    assert_equal null_value, Actor::Configuration::NullValue.new
    assert_respond_to null_value, :anything
    assert_same null_value, null_value.anything.deeply.missing
    assert_equal "enabled", configuration[:feature]
    assert_equal "enabled", configuration.feature
    assert_respond_to configuration, :feature
    assert_equal configuration, same
    assert_equal configuration.hash, same.hash
  end

  test "actor preferences decode the realm snapshot and cookie input forms" do
    preference = Actor::Preference.from_jwt(
      {
        "language" => "en",
        "region" => "us",
        "timezone" => "Etc/UTC",
        "theme" => "dark",
        "currency" => "usd",
        "date_format" => "us",
        "time_format" => "12",
        "motion" => "reduced",
        "density" => "compact",
        "page_size" => "infinity",
      },
    )
    same = Actor::Preference.from_jwt(
      {
        "language" => "en",
        "region" => "us",
        "timezone" => "Etc/UTC",
        "theme" => "dark",
        "currency" => "usd",
        "date_format" => "us",
        "time_format" => "12",
        "motion" => "reduced",
        "density" => "compact",
        "page_size" => "infinity",
      },
    )

    assert_equal "en", preference.language
    assert_equal "us", preference.region
    assert_equal "dr", preference.theme
    assert_equal preference, same
    assert_equal preference.hash, same.hash

    cookie = Actor::Preference::Cookie.new(
      consented: true, functional: true, performant: false, targetable: false,
      consent_version: 1, consented_at: Time.zone.parse("2026-07-18 08:00:00"),
    )

    assert_same cookie, Actor::Preference.cookie_from(cookie)

    from_hash = preference.with_cookie(
      consented: true,
      functional: true,
      performant: false,
      targetable: false,
      consent_version: 1,
      consented_at: Time.zone.parse("2026-07-18 08:00:00"),
    )

    assert_predicate from_hash.cookie, :consented?
    assert_predicate from_hash.cookie, :functional?
  end

  test "privacy request defaults scopes cancellation and legal hold are executable" do
    request = ClientPrivacyRequest.new

    assert_not request.valid?
    assert_equal "erasure", request.request_kind
    assert_equal "self_service", request.request_source
    assert_equal "unknown", request.jurisdiction
    assert_equal ClientPrivacyRequest.status_id_for("RECEIVED"), request.status_id
    assert_predicate request, :received?
    assert_kind_of ActiveRecord::Relation, ClientPrivacyRequest.open_for_recovery_block
    assert_kind_of ActiveRecord::Relation, ClientPrivacyRequest.open_for_hold_block

    updates = []
    request.stub(:update!, ->(attributes) { updates << attributes }) do
      now = Time.zone.parse("2026-07-18 08:00:00")
      request.cancel_from_recovery!(now: now)
      request.block_by_legal_hold!(now: now)
    end

    assert_equal ClientPrivacyRequest.status_id_for("CANCELLED"), updates.first[:status_id]
    assert_equal ClientPrivacyRequest.status_id_for("BLOCKED_BY_LEGAL_HOLD"), updates.last[:status_id]
  end

  test "retainable discard now validates duration and clamps to persisted creation" do
    record = AppPreferenceChronicle.new(created_at: 1.minute.from_now)

    assert_raises(ArgumentError) { record.discard_now!(purge_after: 10) }

    updates = []
    record.stub(:update!, ->(attributes) { updates << attributes }) do
      now = Time.current
      record.discard_now!(purge_after: 1.day, now: now)
    end

    assert_equal record.created_at, updates.last[:discard_at]
    assert_operator updates.last[:purge_eligible_at], :>, updates.last[:discard_at]
  end

  test "preference value records apply their default option ids" do
    classes = [
      ClientPreferenceAdultContentGate, ClientPreferenceDateFormat, ClientPreferenceDensity,
      ClientPreferenceLanguage, ClientPreferenceMotion, ClientPreferencePageSize, ClientPreferenceRegion,
      ClientPreferenceTheme, ClientPreferenceTimeFormat, ClientPreferenceTimezone,
      ComPreferenceAdultContentGate, ComPreferenceCurrency, ComPreferenceDateFormat, ComPreferenceDensity,
      ComPreferenceMotion, ComPreferencePageSize, ComPreferenceTimeFormat,
      OperatorPreferenceAdultContentGate, OperatorPreferenceDateFormat, OperatorPreferenceDensity,
      OperatorPreferenceMotion, OperatorPreferencePageSize, OperatorPreferenceRegion,
      OperatorPreferenceTheme, OperatorPreferenceTimeFormat, OperatorPreferenceTimezone,
      OrgPreferenceAdultContentGate, OrgPreferenceCurrency, OrgPreferenceDateFormat, OrgPreferenceDensity,
      OrgPreferenceMotion, OrgPreferencePageSize, OrgPreferenceTimeFormat,
    ]

    classes.each do |model_class|
      record = model_class.new
      record.valid?

      assert_predicate record.option_id, :present?, "#{model_class} should assign a default option"
    end
  end

  test "preference reference records ensure their fixed defaults" do
    classes = [
      ClientPreferenceDateFormatOption, ClientPreferenceDensityOption, ClientPreferenceMotionOption,
      ClientPreferencePageSizeOption, ClientPreferenceTimeFormatOption,
      ComPreferenceDateFormatOption, ComPreferenceDensityOption, ComPreferenceLanguageOption,
      ComPreferenceMotionOption, ComPreferencePageSizeOption, ComPreferenceRegionOption,
      ComPreferenceTimeFormatOption,
      OperatorPreferenceDateFormatOption, OperatorPreferenceDensityOption, OperatorPreferenceMotionOption,
      OperatorPreferencePageSizeOption, OperatorPreferenceTimeFormatOption,
      OrgPreferenceDateFormatOption, OrgPreferenceDensityOption, OrgPreferenceMotionOption,
      OrgPreferencePageSizeOption, OrgPreferenceRegionOption, OrgPreferenceThemeOption,
      OrgPreferenceTimeFormatOption,
    ]

    classes.each do |model_class|
      model_class.ensure_defaults!

      assert_equal model_class::DEFAULTS.sort, model_class.where(id: model_class::DEFAULTS).pluck(:id).sort
    end
  end

  test "withdrawal occurrence records an allowlisted context for each supported surface" do
    created_attributes = nil
    status_class = Object.new
    status_class.define_singleton_method(:ensure_defaults!) { true }
    occurrence_class = Object.new
    occurrence_class.define_singleton_method(:create!) { |attributes| created_attributes = attributes }
    subject = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, public_id: "client-occurrence")
    request = Struct.new(:request_id, :user_agent).new("request-id", "agent")

    WithdrawalOccurrenceRecording.stub(:occurrence_class_for, occurrence_class) do
      WithdrawalOccurrenceRecording.stub(:occurrence_status_class_for, status_class) do
        WithdrawalOccurrenceRecording.stub(:occurrence_status_id_for, 1) do
          WithdrawalOccurrenceRecording.record!(
            subject: subject,
            event_type: :requested,
            request: request,
            context: { reason_code: "self_service", forbidden: "discarded" },
          )
        end
      end
    end

    assert_equal 1, created_attributes[:status_id]
    assert_equal "requested", created_attributes[:event_type]
    assert_equal "app", created_attributes[:context]["surface"]
    assert_equal "self_service", created_attributes[:context]["reason_code"]
    assert_not created_attributes[:context].key?("forbidden")
    assert_equal ClientOccurrence, WithdrawalOccurrenceRecording.occurrence_class_for(subject)
  end

  test "avatar group and memberships expose state and timestamp validation" do
    group = AvatarGroup.new(state: "active", archived_at: Time.current)

    assert_not group.active?
    assert_not group.archived?
    assert_not group.valid?
    assert_includes group.errors.details[:archived_at], { error: :present }

    archived = AvatarGroup.new(state: "archived", archived_at: nil)

    assert_not archived.valid?
    assert_includes archived.errors.details[:archived_at], { error: :blank }

    membership = GroupAvatarMembership.new(
      state: "removed", assigned_at: Time.current, removed_at: nil,
    )

    assert_not membership.active?
    assert_not membership.valid?
    assert_includes membership.errors.details[:removed_at], { error: :blank }

    invalid_time = GroupAvatarMembership.new(
      state: "active", assigned_at: Time.current, removed_at: 1.minute.ago,
    )

    assert_not invalid_time.valid?
    assert_includes invalid_time.errors.details[:removed_at], { error: :invalid }
    assert_includes invalid_time.errors.details[:removed_at], { error: :present }
  end

  test "retention hold and processor notification defaults and transitions are complete" do
    hold = ClientRetentionHold.new

    assert_not hold.valid?
    assert_equal "legal_hold", hold.hold_kind
    assert_equal "legal_hold", hold.reason_code
    assert_equal ClientRetentionHold.status_id_for("ACTIVE"), hold.status_id
    assert_predicate hold.applied_at, :present?
    assert_kind_of ActiveRecord::Relation, ClientRetentionHold.active_at(Time.current)

    notification = ClientProcessorErasureNotification.new(retry_count: 0)

    assert_not notification.valid?
    assert_equal ClientProcessorErasureNotification.status_id_for("PENDING"), notification.status_id
    assert_predicate notification.requested_at, :present?

    assert_equal 1, notification.delivery_generation

    notification.status_id = ClientProcessorErasureNotification.status_id_for("RETRYABLE_FAILURE")

    assert_predicate notification, :retryable_failure?

    notification.status_id = ClientProcessorErasureNotification.status_id_for("PERMANENT_FAILURE")

    assert_predicate notification, :permanent_failure?

    notification.status_id = ClientProcessorErasureNotification.status_id_for("SKIPPED")

    assert_predicate notification, :terminal?
  end

  test "small public model APIs and reference defaults are covered by model tests" do
    AppPreferenceChronicleEvent.ensure_defaults!
    ComPreferenceChronicleEvent.ensure_defaults!
    OrgPreferenceChronicleEvent.ensure_defaults!

    assert_predicate OperatorSecretCredential.generate_raw_secret_credential, :present?
    assert_equal :operator, OperatorEmail.new.promotional_unsubscribe_scope
    assert_equal "public", Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, public_id: "public").to_param
    assert_nil AppPreference.new.app_preference_adult_content_gate
    assert_nil ClientPreference.new.client_preference_adult_content_gate
    assert_not ClientSecretCredential.new.available_at?(at: Client.database_now)
  end

  test "withdrawal ceremony issue and expiration use the model boundary" do
    subject = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)
    created = Object.new
    attributes = nil

    ClientWithdrawalCeremony.stub(
      :create!, ->(**values) {
                  attributes = values
                  created
                },
    ) do
      assert_same created, ClientWithdrawalCeremony.issue!(subject: subject)
    end
    assert_same subject, attributes[:client]

    ceremony = ClientWithdrawalCeremony.new(
      status_id: WithdrawalCeremonyRecordable::STATUS_ACTIVE,
      expires_at: 1.minute.ago,
    )

    assert_predicate ceremony, :expired?
  end

  test "org preference chronicle defaults its actor to its subject" do
    preference = OrgPreference.new(id: 123)
    chronicle = OrgPreferenceChronicle.new(subject_id: 123, subject_type: "OrgPreference")

    chronicle.stub(:org_preference, preference) do
      chronicle.default_actor_to_preference
    end

    assert_same preference, chronicle.actor
  end

  test "withdrawal ceremony defaults authenticate and state changes are deterministic" do
    Time.zone.parse("2026-07-18 08:00:00")
    subject = Struct.new(:withdrawal_in_progress?, :terminated?).new(true, false)
    ceremony = ClientWithdrawalCeremony.new(status_id: WithdrawalCeremonyRecordable::STATUS_ACTIVE)

    ceremony.stub(:subject, subject) do
      assert_not ceremony.valid?
      assert_equal "status", ceremony.purpose
      assert_operator ceremony.expires_at, :>, Time.current
      assert_predicate ceremony.plaintext_token, :present?
      assert ceremony.token_matches?(ceremony.plaintext_token)
      assert_predicate ceremony, :subject_withdrawal_restricted?
    end

    updates = []
    ceremony.stub(:update!, ->(attributes) { updates << attributes }) do
      ceremony.consume!
      ceremony.revoke!
    end

    assert_equal WithdrawalCeremonyRecordable::STATUS_CONSUMED, updates.first[:status_id]
    assert_equal WithdrawalCeremonyRecordable::STATUS_REVOKED, updates.last[:status_id]

    ClientWithdrawalCeremony.stub(:find_by, ceremony) do
      ceremony.stub(:active?, true) do
        ceremony.stub(:token_matches?, true) do
          ceremony.stub(:subject_withdrawal_restricted?, true) do
            assert_equal ceremony,
                         ClientWithdrawalCeremony.authenticate(public_id: "public", token: "token")
          end
        end
      end
    end

    assert_nil ClientWithdrawalCeremony.authenticate(public_id: nil, token: "token")
    assert_nil ClientWithdrawalCeremony.digest_optional(nil)
    assert_equal ClientWithdrawalCeremony.digest_token("ip"), ClientWithdrawalCeremony.digest_optional("ip")
  end

  test "withdrawal ceremony predicates cover expired consumed revoked and mismatched tokens" do
    now = Time.current
    ceremony = ClientWithdrawalCeremony.new(
      status_id: WithdrawalCeremonyRecordable::STATUS_EXPIRED,
      expires_at: now + 1.hour,
      token_digest: "short",
      consumed_at: now,
      revoked_at: now,
    )

    assert_predicate ceremony, :expired?
    assert_predicate ceremony, :consumed?
    assert_predicate ceremony, :revoked?
    assert_not ceremony.active?
    assert_not ceremony.token_matches?(nil)
    assert_not ceremony.token_matches?("different-length-token")
  end
end
