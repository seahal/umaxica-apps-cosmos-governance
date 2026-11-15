# typed: false
# frozen_string_literal: true

require "digest"

# Applies a verified back-channel Logout Token to one Base RP cell's own store. In one writer
# transaction it records the replay receipt, writes an absorbing SID tombstone, and revokes local
# sessions before the HTTP endpoint acknowledges the event.
class RpCellSessionRevoker
  RECEIPT_EVENT_TYPE = "backchannel_logout"
  BASE_CELL_CONNECTIONS = %w(rp_base_app rp_base_org).freeze
  private_constant :BASE_CELL_CONNECTIONS

  class EventConflict < StandardError; end

  def initialize(cell:, payload:)
    @cell = validate_cell!(cell)
    @payload = payload
    validate_payload!
  end

  def self.call(...) = new(...).call
  public_class_method :call

  public

  def call
    record_class.connected_to(role: :writing) do
      begin
        record_class.transaction do
          keys = receipt_keys
          existing = model(:EventReceipt).includes(:op_session_binding).find_by(keys)
          next duplicate_or_conflict!(existing) if existing

          anchor = lock_anchor!
          existing = model(:EventReceipt).includes(:op_session_binding).find_by(keys)
          next duplicate_or_conflict!(existing) if existing

          now = record_class.database_now
          anchor.update!(revoked_at: anchor.revoked_at || now)
          model(:Session).where(op_session_binding_id: anchor.id, revoked_at: nil).lock.each do |session|
            session.update!(revoked_at: now)
          end
          model(:EventReceipt).create!(
            keys.merge(
              op_session_binding: anchor,
              expires_at: Time.zone.at(payload.fetch("exp")),
              committed_at: now,
            ),
          )
          :revoked
        end
      rescue ActiveRecord::RecordNotUnique
        committed_receipt_after_race!
      rescue ActiveRecord::RecordInvalid => e
        raise unless e.record.errors.added?(:jti_digest, :taken)

        committed_receipt_after_race!
      end
    end
  end

  private

  attr_reader :cell, :payload

  def validate_payload!
    raise ArgumentError, "Logout Token payload must be an object" unless payload.is_a?(Hash)

    validate_required_claims!
    validate_no_nonce!
    validate_client_identity!
    validate_logout_event!
    validate_claim_types!
    validate_identifier_lengths!
  end

  def validate_required_claims!
    required = %w(iss aud iat exp jti sid events)
    missing = required.reject { |key| payload[key].present? }
    raise ArgumentError, "Logout Token payload is missing required RP claims" if missing.any?
  end

  def validate_no_nonce!
    raise ArgumentError, "Logout Token payload must not contain nonce" if payload.key?("nonce")
  end

  def validate_client_identity!
    raise ArgumentError, "Logout Token audience is not the registered RP client" unless
      payload.fetch("aud") == [cell.client_id]
  end

  def validate_logout_event!
    unless payload.fetch("events").is_a?(Hash) &&
        payload.fetch("events")[OidcOpLogoutTokenVerifier::EVENT].is_a?(Hash)
      raise ArgumentError, "Logout Token does not contain the required back-channel logout event"
    end
  end

  def validate_claim_types!
    unless payload.fetch("iss").is_a?(String) && payload.fetch("sid").is_a?(String) &&
        payload.fetch("jti").is_a?(String) && payload.fetch("iat").is_a?(Numeric) &&
        payload.fetch("exp").is_a?(Numeric)
      raise ArgumentError, "Logout Token RP claims have invalid types"
    end
  end

  def validate_identifier_lengths!
    binding_columns = model(:OpSessionBinding).columns_hash
    if payload.fetch("sid").bytesize > binding_columns.fetch("sid").limit ||
        payload.fetch("iss").bytesize > binding_columns.fetch("issuer").limit
      raise ArgumentError, "Logout Token identifiers exceed the RP schema"
    end
    raise ArgumentError, "Logout Token JTI is too long" if
      payload.fetch("jti").bytesize > OidcOpLogoutTokenVerifier::MAX_IDENTIFIER_LENGTH
  end

  def lock_anchor!
    keys = {
      issuer: payload.fetch("iss"), realm: cell.realm, client_id: cell.client_id, sid: payload.fetch("sid"),
    }
    binding_class = model(:OpSessionBinding)
    binding = binding_class.find_by(keys)
    unless binding
      begin
        record_class.transaction(requires_new: true) do
          now = record_class.database_now
          binding = binding_class.create!(keys.merge(created_at: now, updated_at: now))
        end
      rescue ActiveRecord::RecordNotUnique
        binding = binding_class.find_by!(keys)
      rescue ActiveRecord::RecordInvalid => e
        raise unless e.record.errors.added?(:sid, :taken)

        binding = binding_class.find_by!(keys)
      end
    end
    binding.lock!
  end

  def receipt_keys
    {
      issuer: payload.fetch("iss"),
      realm: cell.realm,
      client_id: cell.client_id,
      event_type: RECEIPT_EVENT_TYPE,
      jti_digest: Digest::SHA256.digest(payload.fetch("jti")),
    }
  end

  def duplicate_or_conflict!(receipt)
    return :duplicate if receipt.op_session_binding.sid == payload.fetch("sid")

    raise EventConflict, "Logout Token JTI was already committed for another SID"
  end

  def committed_receipt_after_race!
    record_class.uncached do
      receipt = model(:EventReceipt).includes(:op_session_binding).find_by!(receipt_keys)
      duplicate_or_conflict!(receipt)
    end
  end

  def validate_cell!(candidate)
    unless candidate.is_a?(RpCellBinding::Cell) && BASE_CELL_CONNECTIONS.include?(candidate.connection) &&
        RpCellBinding.fetch(candidate.connection) == candidate
      raise ArgumentError, "session revoker requires a registered Base RP cell"
    end

    candidate
  end

  def record_class
    "#{cell.record_prefix}Record".constantize
  end

  def model(suffix)
    "#{cell.record_prefix}#{suffix}".constantize
  end
end
