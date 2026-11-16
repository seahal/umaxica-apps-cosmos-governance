# frozen_string_literal: true

# Purges only Governance-owned cohorts; missing remote retention authority never permits deletion.
class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  DEFAULT_BATCH_SIZE = 500

  MAX_BATCH_SIZE = 500

  RETAINABLE_MODELS = [
    AppPreferenceChronicle, OrgPreferenceChronicle, ClientChronicle,
    OperatorChronicle, ClientWithdrawalFlow, ClientProcessorErasureNotification,
    ClientPrivacyRequest, ClientRetentionHold, ClientSecretCredential,
    OperatorSecretCredential, Avatar, Member,
    OperatorWorkspaceAccount, AppPreference, OrgPreference,
    ClientEmail, ClientTelephone, ClientPasskey,
    AreaOccurrence, ClientOccurrence, VisitorOccurrence,
    OperatorOccurrence, ZipOccurrence, DomainOccurrence,
    IpOccurrence, EmailOccurrence, JwtOccurrence,
    TelephoneOccurrence, Client, Operator,
  ].freeze

  FEATURE_NAME = :retention_purge_suspended

  public

  def perform(batch_size: DEFAULT_BATCH_SIZE)
    limit = normalized_batch_size(batch_size)
    unless limit&.between?(1, MAX_BATCH_SIZE)
      raise ArgumentError, "batch_size must be between 1 and #{MAX_BATCH_SIZE}"
    end

    if FeatureFlags.enabled?(FEATURE_NAME)
      Rails.logger.warn(JitLogEvent.format("retention.purge.suspended"))
      return
    end

    failures = []
    if ClientSecretAuditOutbox.exists?
      begin
        ClientSecretAuditDeliveryJob.perform_now(
          batch_size: limit, retention_seconds: ClientSecretLifetimesValue.outbox_retention.to_i,
        )
      rescue StandardError => e
        failures << e
        Rails.error.report(e, handled: false, context: { job: self.class.name, phase: "secret_audit_delivery" })
      end
    end
    if ClientSecretIssuance.exists? || ClientSecretCredential.exists? || ClientSecretAuditOutbox.exists?
      begin
        ClientSecretLifecycleJob.perform_now(batch_size: limit)
      rescue AccessOpDataUnavailableError => e
        failures << e
      end
    end

    RETAINABLE_MODELS.each do |klass|
      purge_retained_model(klass, batch_size: limit)
    rescue StandardError => e
      failures << e
      Rails.error.report(
        e,
        handled: false,
        context: { job: self.class.name, retained_model: klass.name, batch_size: limit },
      )
    end
    raise failures.first if failures.any?
  end

  private

  def purge_retained_model(klass, batch_size:)
    now = klass.database_now
    return if klass == ClientSecretCredential
    return if purge_special_retained_model(klass, now: now, batch_size: batch_size)
    return unless klass.column_names.include?("purge_eligible_at")

    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size).delete_all
  end

  def purge_special_retained_model(klass, now:, batch_size:)
    if klass == ClientEmail
      purge_email_identifiers(klass, now:, batch_size:)
    elsif klass == ClientTelephone
      purge_telephone_identifiers(klass, now:, batch_size:)
    elsif klass == Avatar
      purge_avatars(now:, batch_size:)
    elsif klass == Client
      preserve_client_purge_decisions(now:, batch_size:)
    elsif [Operator, ClientPasskey, OperatorSecretCredential].include?(klass)
      # Remote holds and retained authentication evidence cannot be inferred from local absence.
      raise AccessOpDataUnavailableError if klass.exists?(purge_eligible_at: ..now)
    else
      return false
    end
    true
  end

  def preserve_client_purge_decisions(now:, batch_size:)
    eligible = Client.where(purge_eligible_at: ..now)
    eligible.in_batches(of: batch_size) do |batch|
      batch.each do |client|
        client.with_lock do
          decision_time = Client.database_now
          next unless client.lapsed?(decision_time) && client.purgeable?(decision_time)

          hold = ClientRetentionHold.active_at(decision_time).find_by(client_id: client.id)
          if hold
            ClientPrivacyRequest.where(client_id: client.id).open_for_hold_block.find_each do |request|
              request.block_by_legal_hold!(retention_exception_code: hold.reason_code, now: decision_time)
              WithdrawalOccurrenceRecording.record!(
                subject: client, event_type: "privacy_erasure.blocked_by_legal_hold",
                context: { privacy_request_public_id: request.public_id,
                           retention_hold_public_id: hold.public_id,
                           retention_exception_code: request.retention_exception_code, },
              )
            end
            WithdrawalOccurrenceRecording.record!(
              subject: client, event_type: "withdrawal.purge_skipped_by_hold",
              context: { retention_hold_public_id: hold.public_id, reason_code: hold.reason_code },
            )
          elsif AppEnforcementCase.principal_effect_blocking?(client.public_id, :withdrawal_purge_blocked) ||
              AppEnforcementCase.principal_effect_blocking?(client.public_id, :principal_hard_delete_blocked)
            WithdrawalOccurrenceRecording.record!(
              subject: client,
              event_type: "withdrawal.purge_skipped_by_enforcement",
            )
          elsif ClientEmail.exists?(user_id: client.id) || ClientTelephone.exists?(user_id: client.id)
            WithdrawalOccurrenceRecording.record!(
              subject: client, event_type: "withdrawal.purge_deferred",
              context: { reason_code: "identifier_retention" },
            )
          end
        end
      end
    end
    raise AccessOpDataUnavailableError if eligible.exists?
  end

  def purge_email_identifiers(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.each { |email| EmailIdentifierPurger.call(record: email) }
    end
  end

  def purge_telephone_identifiers(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.each { |telephone| TelephoneIdentifierPurger.call(record: telephone) }
    end
  end

  def purge_avatars(now:, batch_size:)
    Avatar.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.each do |candidate|
        AvatarRecord.transaction do
          avatar = Avatar.lock.find_by(id: candidate.id)
          next unless avatar

          reason =
            if avatar.enterprise_ownership_periods.exists? || avatar.bureau_ownership_periods.exists?
              "ownership_history"
            else
              "retention_policy_pending"
            end
          AvatarPurgeDeferral.record!(avatar: avatar, reason_code: reason)
        end
      end
    end
  end

  def normalized_batch_size(value)
    return value if value.is_a?(Integer)
    return Integer(value) if value.is_a?(String)

    nil
  rescue ArgumentError, TypeError
    nil
  end
end
