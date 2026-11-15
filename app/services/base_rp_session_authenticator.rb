# typed: false
# frozen_string_literal: true

# Authenticates a Base RP request from that realm's live local session only.
class BaseRpSessionAuthenticator
  Result =
    Data.define(:status, :principal, :session, :payload) do
      def authenticated? = status == :authenticated
    end

  CELL_STORAGE = {
    "rp_base_app" => {
      cell: RpCellBinding.fetch("rp_base_app"),
      record: RpBaseAppRecord,
      session: RpBaseAppSession,
      principal: RpBaseAppPrincipal,
      resource_type: "client",
    }.freeze,
    "rp_base_org" => {
      cell: RpCellBinding.fetch("rp_base_org"),
      record: RpBaseOrgRecord,
      session: RpBaseOrgSession,
      principal: RpBaseOrgPrincipal,
      resource_type: "operator",
    }.freeze,
  }.freeze

  def initialize(cell:, local_session_id:, issuer:)
    @storage = cell.is_a?(RpCellBinding::Cell) && CELL_STORAGE[cell.connection]
    raise ArgumentError, "Base RP session authentication requires a registered Base cell" unless
      @storage && @storage.fetch(:cell) == cell

    @local_session_id = local_session_id
    raise ArgumentError, "Base RP session authentication requires the configured Visa issuer" unless
      issuer.is_a?(String) && issuer.present?

    @issuer = issuer
  end

  class << self
    public

    def call(...) = new(...).call
  end

  public

  def call
    return result(:missing) if local_session_id.blank?

    record_class.connected_to(role: :writing) do
      session = session_class.includes(
        :authentication_evidence, op_session_binding: { identity_binding: :principal },
      ).find_by(public_id: local_session_id.to_s)
      next result(:invalid) unless session&.active?(now: record_class.database_now)

      binding = session.op_session_binding
      identity = binding&.identity_binding
      principal = identity&.principal
      evidence = session.authentication_evidence
      next result(:invalid) unless valid_binding?(binding, identity, principal) && valid_evidence?(evidence)

      Result.new(
        status: :authenticated, principal:, session:,
        payload: authentication_claims(binding, identity, evidence, session),
      )
    end
  end

  private

  attr_reader :storage, :local_session_id, :issuer

  def record_class = storage.fetch(:record)

  def session_class = storage.fetch(:session)

  def valid_binding?(binding, identity, principal)
    binding && binding.revoked_at.nil? && identity && principal && principal.disabled_at.nil? &&
      binding.identity_binding_id == identity.id && identity.principal_id == principal.id &&
      binding.issuer == identity.issuer && identity.realm == storage.fetch(:cell).realm &&
      binding.realm == storage.fetch(:cell).realm && identity.client_id == storage.fetch(:cell).client_id &&
      binding.client_id == storage.fetch(:cell).client_id &&
      binding.issuer == issuer &&
      identity.subject.present? && binding.sid.present?
  end

  def valid_evidence?(evidence)
    evidence && evidence.authentication_context == AuthenticationContextValue::NORMAL_KEY &&
      evidence.acr.present? && evidence.amr.is_a?(Array) && evidence.amr.present? &&
      evidence.amr.all? { |method| method.is_a?(String) && method.present? } && evidence.auth_time.positive?
  end

  def authentication_claims(binding, identity, evidence, session)
    {
      "iss" => binding.issuer,
      "sub" => identity.subject,
      "aud" => [storage.fetch(:cell).client_id],
      "client_id" => storage.fetch(:cell).client_id,
      "realm" => storage.fetch(:cell).realm,
      "act" => storage.fetch(:resource_type),
      "sid" => binding.sid,
      "jti" => evidence.id_token_jti_digest,
      "acr" => evidence.acr,
      "amr" => evidence.amr,
      "auth_time" => evidence.auth_time,
      "authn_ctx" => evidence.authentication_context,
      "iat" => evidence.auth_time,
      "exp" => session.absolute_expires_at.to_i,
    }.freeze
  end

  def result(status)
    Result.new(status:, principal: nil, session: nil, payload: nil)
  end
end
