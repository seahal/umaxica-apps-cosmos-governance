# typed: false
# frozen_string_literal: true

# Atomically consumes a front-channel ID Token jti and commits its RP session and claims.
class RpCallbackCommitter
  class ExpiredCallback < StandardError; end
  private_constant :ExpiredCallback

  CellStore = Data.define(
    :cell, :record_class, :binding_class, :identity_binding_class, :principal_class, :session_class,
    :consumed_jti_class, :authentication_evidence_class,
  )
  private_constant :CellStore

  CELL_STORES = {
    "rp_base_app" => CellStore.new(
      cell: RpCellBinding.fetch("rp_base_app"), record_class: RpBaseAppRecord,
      binding_class: RpBaseAppOpSessionBinding, identity_binding_class: RpBaseAppIdentityBinding,
      principal_class: RpBaseAppPrincipal, session_class: RpBaseAppSession,
      consumed_jti_class: RpBaseAppConsumedIdTokenJti,
      authentication_evidence_class: RpBaseAppSessionAuthenticationEvidence,
    ),
    "rp_base_org" => CellStore.new(
      cell: RpCellBinding.fetch("rp_base_org"), record_class: RpBaseOrgRecord,
      binding_class: RpBaseOrgOpSessionBinding, identity_binding_class: RpBaseOrgIdentityBinding,
      principal_class: RpBaseOrgPrincipal, session_class: RpBaseOrgSession,
      consumed_jti_class: RpBaseOrgConsumedIdTokenJti,
      authentication_evidence_class: RpBaseOrgSessionAuthenticationEvidence,
    ),
  }.freeze
  private_constant :CELL_STORES

  Result =
    Data.define(:outcome, :session, :principal) do
      def success? = session.present?
    end

  OUTCOMES = %i(committed renewed already_enrolled revoked binding_mismatch replayed).freeze

  def initialize(cell:, issuer:, subject:, sid:, absolute_expires_at:, id_token_jti_digest:,
                 id_token_expires_at:, authentication_evidence:, renewal_session_id: nil)
    @store = validate_cell!(cell)
    @issuer = require_value(issuer, "issuer")
    @subject = require_value(subject, "subject")
    @sid = require_value(sid, "sid")
    @absolute_expires_at = require_time(absolute_expires_at, "absolute_expires_at")
    @id_token_jti_digest = require_digest(id_token_jti_digest)
    @id_token_expires_at = require_time(id_token_expires_at, "id_token_expires_at")
    @authentication_evidence = validate_authentication_evidence!(authentication_evidence)
    @renewal_session_id = renewal_session_id
  end

  def self.call(...) = new(...).call
  public_class_method :call

  public

  def call
    record_class.connected_to(role: :writing) do
      record_class.transaction(requires_new: true) do
        now = record_class.database_now
        raise ExpiredCallback if id_token_expires_at <= now || absolute_expires_at <= now

        prune_expired_receipts!(now)
        consume_jti!(now)
        anchor = lock_anchor!(now)
        next result(:revoked) if anchor.revoked_at

        identity_binding = resolve_or_check_identity_binding!(anchor)
        next identity_binding if identity_binding.is_a?(Result)
        next result(:revoked) if identity_binding.principal.disabled_at

        session_result = reuse_or_renew_session(
          existing_session_for(anchor), identity_binding.principal, now,
        )
        next session_result if session_result

        session_class.where(op_session_binding_id: anchor.id, revoked_at: nil).lock.each do |previous_session|
          previous_session.update!(revoked_at: now)
        end
        session = session_class.create!(
          op_session_binding: anchor, absolute_expires_at:, installed_generation: 0,
        )
        write_authentication_evidence!(session)
        Result.new(outcome: :committed, session:, principal: identity_binding.principal)
      end
    end
  rescue ExpiredCallback
    result(:revoked)
  rescue ActiveRecord::RecordInvalid => e
    raise unless e.record.is_a?(consumed_jti_class) && e.record.errors.of_kind?(:jti_digest, :taken)

    result(:replayed)
  rescue ActiveRecord::RecordNotUnique
    result(:replayed)
  end

  private

  attr_reader :store, :issuer, :subject, :sid, :absolute_expires_at, :id_token_jti_digest,
              :id_token_expires_at, :authentication_evidence, :renewal_session_id

  def record_class = store.record_class

  def binding_class = store.binding_class

  def identity_binding_class = store.identity_binding_class

  def principal_class = store.principal_class

  def session_class = store.session_class

  def consumed_jti_class = store.consumed_jti_class

  def authentication_evidence_class = store.authentication_evidence_class

  def lock_anchor!(now)
    keys = { issuer:, realm: store.cell.realm, client_id: store.cell.client_id, sid: }
    binding = binding_class.find_by(keys)
    return binding.lock! if binding

    begin
      record_class.transaction(requires_new: true) do
        binding = binding_class.create!(keys.merge(created_at: now, updated_at: now))
      end
    rescue ActiveRecord::RecordNotUnique
      binding = binding_class.find_by!(keys)
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record.errors.added?(:sid, :taken)

      binding = binding_class.find_by!(keys)
    end
    binding.lock!
  end

  def resolve_or_check_identity_binding!(anchor)
    if anchor.identity_binding_id.present?
      binding = identity_binding_class.includes(:principal).lock.find(anchor.identity_binding_id)
      expected = [issuer, store.cell.realm, store.cell.client_id, subject]
      actual = [binding.issuer, binding.realm, binding.client_id, binding.subject]
      return result(:binding_mismatch) unless actual == expected

      return binding
    end

    keys = { issuer:, realm: store.cell.realm, client_id: store.cell.client_id, subject: }
    binding = identity_binding_class.includes(:principal).lock.find_by(keys)
    unless binding
      principal = principal_class.create!
      binding = identity_binding_class.create_or_find_by!(keys) { |candidate| candidate.principal = principal }
      principal.destroy! unless binding.principal_id == principal.id
      binding.reload
    end
    anchor.update!(identity_binding: binding)
    binding
  end

  def existing_session_for(anchor)
    session_class.where(op_session_binding_id: anchor.id).order(id: :desc).lock.first
  end

  def write_authentication_evidence!(session)
    evidence = authentication_evidence_class.find_or_initialize_by(rp_session_id: session.id)
    evidence.assign_attributes(authentication_evidence.merge(authentication_context: AuthenticationContextValue::NORMAL_KEY))
    evidence.save!
  end

  def consume_jti!(now)
    consumed_jti_class.create!(
      jti_digest: id_token_jti_digest, expires_at: id_token_expires_at, created_at: now, updated_at: now,
    )
  end

  def prune_expired_receipts!(now)
    consumed_jti_class.where(expires_at: ..now).delete_all
  end

  def reuse_or_renew_session(session, principal, now)
    return unless session && session.revoked_at.nil?

    if session.absolute_expires_at > now
      write_authentication_evidence!(session)
      return Result.new(outcome: :already_enrolled, session:, principal:)
    end
    return unless renewal_session_id == session.public_id

    session.update!(absolute_expires_at:, installed_generation: session.installed_generation + 1)
    write_authentication_evidence!(session)
    Result.new(outcome: :renewed, session:, principal:)
  end

  def validate_cell!(candidate)
    store = candidate.is_a?(RpCellBinding::Cell) && CELL_STORES[candidate.connection]
    raise ArgumentError, "callback committer requires a registered Base RP cell" unless store&.cell == candidate

    store
  end

  def validate_authentication_evidence!(value)
    required = %w(acr amr auth_time id_token_jti_digest)
    raise ArgumentError, "ID Token authentication evidence is invalid" unless value.is_a?(Hash) &&
      value.keys.sort == required.sort && value.fetch("acr").is_a?(String) && value.fetch("acr").present? &&
      value.fetch("amr").is_a?(Array) && value.fetch("amr").present? &&
      value.fetch("amr").all? { |method| method.is_a?(String) && method.present? } &&
      value.fetch("auth_time").is_a?(Integer) &&
      value.fetch("id_token_jti_digest").is_a?(String) &&
      value.fetch("id_token_jti_digest").match?(/\A[0-9a-f]{64}\z/)

    value.transform_keys(&:to_sym).freeze
  end

  def require_value(value, name)
    raise ArgumentError, "#{name} is required" unless value.is_a?(String) && value.present?

    value
  end

  def require_time(value, name)
    return value.to_time if value.respond_to?(:to_time)

    raise ArgumentError, "#{name} must be a time"
  end

  def require_digest(value)
    return value if value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)

    raise ArgumentError, "ID Token jti digest must be a SHA-256 digest"
  end

  def result(outcome)
    raise ArgumentError, "unsupported callback outcome" unless OUTCOMES.include?(outcome)

    Result.new(outcome:, session: nil, principal: nil)
  end
end
