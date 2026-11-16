# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"
# require "helpers/global_test_support"

class RetentionPurgeJobTest < ActiveJob::TestCase
  setup do
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "604800"
  end

  teardown { Flipper.disable(RetentionPurgeJob::FEATURE_NAME) }

  test "generic retention preserves com preferences and their audit history" do
    preference = com_preferences(:one)
    audit = com_preference_chronicles(:one)
    preference.update!(last_issued_at: 433.days.ago, last_issued_expires_at: 33.days.ago)
    audit.update!(created_at: 3.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago)

    assert_raises(AccessOpDataUnavailableError) { RetentionPurgeJob.perform_now }

    assert_predicate ComPreference.where(id: preference.id), :exists?
    assert_predicate ComPreferenceChronicle.where(id: audit.id), :exists?
  end

  test "Avatar purge deferral preserves encrypted moniker history" do
    handle = Handle.create!(
      handle: "purge-avatar-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = AvatarTestFactory.create!(
      moniker: "Purge",
      capability: AvatarCapability.find(AvatarCapability::NORMAL),
      active_handle: handle,
    )
    former_moniker = avatar.avatar_monikers.create!(
      moniker: "Former",
      valid_from: Time.utc(2024, 1, 1),
      valid_to: Time.utc(2025, 1, 1),
    )
    current_moniker = AvatarMoniker.current.find_by!(avatar_id: avatar.id)
    avatar.update_columns(purge_eligible_at: 1.hour.ago)

    assert_no_difference -> { Avatar.count } do
      assert_no_difference -> { AvatarMoniker.count } do
        assert_raises(AccessOpDataUnavailableError) { RetentionPurgeJob.perform_now }
      end
    end

    assert Avatar.exists?(avatar.id)
    assert AvatarMoniker.exists?(former_moniker.id)
    assert AvatarMoniker.exists?(current_moniker.id)
    assert AvatarPurgeDeferral.exists?(avatar_id: avatar.id, reason_code: "ownership_history")
  end

  test "rejects a retention batch size outside the bounded execution range" do
    error =
      assert_raises(ArgumentError) do
        RetentionPurgeJob.perform_now(batch_size: 501)
      end

    assert_equal "batch_size must be between 1 and 500", error.message
  end

  test "rejects fractional retention batch sizes instead of truncating them" do
    error =
      assert_raises(ArgumentError) do
        RetentionPurgeJob.perform_now(batch_size: 1.5)
      end

    assert_equal "batch_size must be between 1 and 500", error.message
  end

  test "rejects zero negative and missing retention batch sizes" do
    [0, -1, nil].each do |batch_size|
      error =
        assert_raises(ArgumentError) do
          RetentionPurgeJob.perform_now(batch_size: batch_size)
        end

      assert_equal "batch_size must be between 1 and 500", error.message
    end
  end

  test "accepts both inclusive retention batch-size boundaries before work" do
    FeatureFlags.stub(:enabled?, true) do
      [1, 500].each do |batch_size|
        assert_nothing_raised { RetentionPurgeJob.perform_now(batch_size:) }
      end
    end
  end

  test "accepts an integral string batch size through the public job interface" do
    FeatureFlags.stub(:enabled?, true) do
      # The validation is exercised before any destructive work is reached. The kill-switch stub
      # keeps this boundary test independent of retention rows while still using the public job
      # entrypoint.
      assert_nothing_raised { RetentionPurgeJob.perform_now(batch_size: "1") }
    end
  end

  test "purges visitor occurrences where purge_eligible_at is in the past" do
    VisitorOccurrenceStatus.ensure_defaults!
    occurrence_to_purge = VisitorOccurrence.create!(body: "purge-#{SecureRandom.hex(8)}")
    occurrence_to_keep = VisitorOccurrence.create!(body: "keep-#{SecureRandom.hex(8)}")

    occurrence_to_purge.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)
    occurrence_to_keep.update_columns(discard_at: Retainable::SENTINEL, purge_eligible_at: Retainable::SENTINEL)

    assert_difference -> { VisitorOccurrence.count }, -1 do
      assert_raises(AccessOpDataUnavailableError) { RetentionPurgeJob.perform_now }
    end

    assert_not VisitorOccurrence.exists?(occurrence_to_purge.id)
    assert VisitorOccurrence.exists?(occurrence_to_keep.id)
  end

  test "all generally purgeable Retainable models are registered in RETAINABLE_MODELS" do
    # Force eager load so every Retainable include block runs and registers.
    Rails.application.eager_load!

    # Com preference history needs lifecycle-specific audit and hold checks before deletion.
    specialized_models = [ComPreference, ComPreferenceChronicle]
    missing =
      (Retainable.registry - RetentionPurgeJob::RETAINABLE_MODELS - specialized_models).reject do |model|
        model.name.to_s.match?(/\A(?:CycleBaseTest|RetainableTest|SecretCredentialConcernTest)::/) ||
          !model.table_exists?
      end

    assert_empty missing,
                 "Models include Retainable but are absent from RetentionPurgeJob::RETAINABLE_MODELS -- " \
                 "rows in these tables will never be physically purged: #{missing.map(&:name).sort.join(", ")}"
  end

  test "a suspended purge deletes nothing and is not an error" do
    Flipper.enable(RetentionPurgeJob::FEATURE_NAME)
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, public_id: PublicId.generate, status_id: ClientStatus::ACTIVE)
    operator_due = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    user.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)
    operator_due.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)

    assert_nothing_raised do
      assert_no_difference -> { Operator.count } do
        RetentionPurgeJob.perform_now
      end
    end

    assert Operator.exists?(operator_due.id)
    assert_nil user.reload.terminated_at
  end
  test "remote dependent actor purge refuses deletion while independent occurrence purge continues" do
    VisitorOccurrenceStatus.ensure_defaults!
    client = clients(:one)
    client.update_columns(discard_at: 2.hours.ago, purge_eligible_at: 1.hour.ago)
    occurrence = VisitorOccurrence.create!(body: "retention-independent")
    occurrence.update_columns(discard_at: 2.hours.ago, purge_eligible_at: 1.hour.ago)

    assert_raises(AccessOpDataUnavailableError) { RetentionPurgeJob.perform_now }

    assert Client.exists?(client.id)
    assert_nil client.reload.terminated_at
    assert_not VisitorOccurrence.exists?(occurrence.id)
  end

  test "remote dependent passkey purge preserves credential and creates no purge audit" do
    passkey = ClientPasskey.create!(
      user: clients(:one), webauthn_id: "retained-passkey", public_key: "public-key",
      sign_count: 0, description: "Retained",
    )
    passkey.update_columns(discard_at: 2.hours.ago, purge_eligible_at: 1.hour.ago)

    assert_no_difference -> { ClientPasskeyAuditOutbox.count } do
      assert_raises(AccessOpDataUnavailableError) { RetentionPurgeJob.perform_now }
    end
    assert ClientPasskey.exists?(passkey.id)
  end
  test "eligible operator secret is preserved while independent occurrence purge continues" do
    credential = operator_secret_credentials(:sample_login)
    credential.update_columns(discard_at: 2.hours.ago, purge_eligible_at: 1.hour.ago)
    VisitorOccurrenceStatus.ensure_defaults!
    occurrence = VisitorOccurrence.create!(body: "operator-secret-independent")
    occurrence.update_columns(discard_at: 2.hours.ago, purge_eligible_at: 1.hour.ago)

    assert_raises(AccessOpDataUnavailableError) { RetentionPurgeJob.perform_now }

    assert OperatorSecretCredential.exists?(credential.id)
    assert_not VisitorOccurrence.exists?(occurrence.id)
  end
end
