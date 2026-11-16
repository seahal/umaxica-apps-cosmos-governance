# frozen_string_literal: true

# RP-cell fixtures retain local session setup and external-token verification.
# Access owns OP issuance and step-up evidence; Governance cannot manufacture either.
module RpCellSessionHelper
  class UnavailableValkeyConnection
    def key(*) = raise Umaxica::Valkey::Unavailable

    def call(*) = raise Umaxica::Valkey::Unavailable
  end

  def install_base_rp_jwks_client(client_id:, access_token:)
    raise ArgumentError, "test verifier supports retained Governance RP clients only" unless
      %w(base-app-ww base-org-ww tech-org-ww).include?(client_id.to_s)

    client = OidcClientRegistry.find!(client_id)
    resource_type = OidcIssuer.resource_type_for_client(client)
    namespace = (resource_type == "operator") ? "BASE_ORG" : "BASE_APP"
    jwks_uri = rp_test_jwks_uri_for(client)
    _claims, header = JWT.decode(access_token, nil, false)
    jwks = JitSecurityJwtJwksService.jwk_set(namespace).deep_stringify_keys
    raise ArgumentError, "Base test signing key is absent from the published keyset" unless
      jwks.fetch("keys").any? { |key| key.fetch("kid") == header.fetch("kid") }

    isolated_limiter = OidcJwksRefetchLimiter.new(connection: UnavailableValkeyConnection.new)
    OidcOpJwksClient::CLIENTS[jwks_uri] = OidcOpJwksClient.new(
      jwks_uri:, fetcher: -> { jwks }, limiter: isolated_limiter,
    )
  end

  # Creates local records needed by request tests without invoking the OIDC callback.
  def seed_rp_cell_session(cell:, issuer:, subject:, sid:, absolute_expires_at:)
    prefix = cell.record_prefix
    record_class = "#{prefix}Record".constantize
    identity_binding_class = "#{prefix}IdentityBinding".constantize
    principal_class = "#{prefix}Principal".constantize
    op_session_binding_class = "#{prefix}OpSessionBinding".constantize
    session_class = "#{prefix}Session".constantize
    identity_keys = { issuer:, realm: cell.realm, client_id: cell.client_id, subject: }
    anchor_keys = identity_keys.except(:subject).merge(sid:)

    record_class.connected_to(role: :writing) do
      record_class.transaction(requires_new: true) do
        identity_binding = identity_binding_class.find_by(identity_keys)
        unless identity_binding
          principal = principal_class.create!
          identity_binding = identity_binding_class.create!(identity_keys.merge(principal:))
        end
        anchor = op_session_binding_class.find_by(anchor_keys)
        raise ArgumentError, "cannot seed a revoked RP session" if anchor&.revoked_at

        anchor ||= op_session_binding_class.create!(anchor_keys.merge(identity_binding:))
        if anchor.identity_binding_id.nil?
          anchor.update!(identity_binding:)
        elsif anchor.identity_binding_id != identity_binding.id
          raise ArgumentError, "RP test session identity binding does not match"
        end
        existing_session = session_class.includes(:op_session_binding)
          .where(op_session_binding: anchor, revoked_at: nil)
          .where("absolute_expires_at > ?", record_class.database_now).order(:id).first
        session = existing_session || session_class.create!(
          op_session_binding: anchor, absolute_expires_at:, installed_generation: 0,
        )
        case cell.connection
        when "rp_base_app"
          write_test_authentication_evidence!(
            RpBaseAppSessionAuthenticationEvidence, session,
          )
        when "rp_base_org"
          write_test_authentication_evidence!(
            RpBaseOrgSessionAuthenticationEvidence, session,
          )
        end
        session
      end
    end
  end

  def write_test_authentication_evidence!(evidence_class, session)
    evidence_class.find_or_create_by!(rp_session_id: session.id) do |evidence|
      evidence.acr = "urn:umaxica:base:normal"
      evidence.amr = ["pwd"]
      evidence.auth_time = Time.current.to_i
      evidence.id_token_jti_digest = Digest::SHA256.hexdigest("rp-session-test:#{session.public_id}")
      evidence.authentication_context = AuthenticationContextValue::NORMAL_KEY
    end
  end

  def seed_rp_browser_session(client:, actor:, sid:, absolute_expires_at:)
    resource_type = OidcIssuer.resource_type_for_client(client)

    seed_rp_cell_session(
      cell: RpCellBinding.for_client(client.client_id), issuer: rp_test_issuer_for(client),
      subject: OidcSubject.for(actor, resource_type:), sid:, absolute_expires_at:,
    )
  end

  def rp_test_issuer_for(client)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    authority =
      case client.client_id
      when RpCellBinding.fetch("rp_base_app").client_id then hosts.visa_service
      when RpCellBinding.fetch("rp_base_org").client_id then hosts.visa_staff
      else return OidcIssuer.for_client(client)
      end
    Oidc::AcmeServiceOrigin.from_configured_host(authority.host, default_scheme: "https").origin
  end

  def rp_test_jwks_uri_for(client)
    return OidcIssuer.jwks_uri(OidcIssuer.resource_type_for_client(client)) unless
      [RpCellBinding.fetch("rp_base_app").client_id,
       RpCellBinding.fetch("rp_base_org").client_id,].include?(client.client_id)

    Oidc::AcmeServiceOrigin.from(rp_test_issuer_for(client), default_scheme: "https").jwks_uri
  end

  # The process role and its deployed contract epoch are process configuration.
  def as_rp_cell(client_id)
    cell = RpCellBinding.for_client(client_id)
    names = %w(UMAXICA_RUNTIME_ROLE UMAXICA_RP_BROWSER_ADMISSION)
    previous = names.index_with { |name| ENV[name] }
    ENV["UMAXICA_RUNTIME_ROLE"] = "#{cell.connection.tr("_", "-")}-#{cell.region}"
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "open"
    OidcOpJwksClient::CLIENTS.clear
    yield
  ensure
    previous&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  def sign_in_rp_cell(_client_id, actor:, root_token:)
    raise AccessOpDataUnavailableError
  end

  def sign_in_rp_cell_headers(_client_id, actor:, root_token:, host:)
    raise AccessOpDataUnavailableError
  end

  def sign_in_rp_cell_with_step_up_evidence(_client_id, actor:, root_token:)
    raise AccessOpDataUnavailableError
  end
end
