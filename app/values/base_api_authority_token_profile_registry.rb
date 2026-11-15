# typed: false
# frozen_string_literal: true

# Fixed caller and target profiles for Governance's own Base authority APIs.
class BaseApiAuthorityTokenProfileRegistry
  Profile = Data.define(
    :cell, :namespace, :resource_type, :record_class, :session_class, :binding_class,
    :identity_binding_class, :principal_class, :authentication_evidence_class,
  )

  TOKEN_TYPE = "umaxica-base-api+jwt"
  MAX_LIFETIME_SECONDS = 300
  CLAIMS = %w(iss aud sub act rp_session_id client_id realm jti iat exp).freeze
  HEADER_KEYS = %w(alg kid typ).freeze
  JTI_FORMAT = /\A[A-Za-z0-9_-]{16,128}\z/
  SESSION_ID_FORMAT = /\A[A-Za-z0-9_-]{#{PublicId::GENERATION_SIZE}}\z/

  APP = Profile.new(
    cell: RpCellBinding.fetch("rp_base_app"), namespace: "BASE_APP", resource_type: "client",
    record_class: RpBaseAppRecord, session_class: RpBaseAppSession,
    binding_class: RpBaseAppOpSessionBinding, identity_binding_class: RpBaseAppIdentityBinding,
    principal_class: RpBaseAppPrincipal, authentication_evidence_class: RpBaseAppSessionAuthenticationEvidence,
  ).freeze
  ORG = Profile.new(
    cell: RpCellBinding.fetch("rp_base_org"), namespace: "BASE_ORG", resource_type: "operator",
    record_class: RpBaseOrgRecord, session_class: RpBaseOrgSession,
    binding_class: RpBaseOrgOpSessionBinding, identity_binding_class: RpBaseOrgIdentityBinding,
    principal_class: RpBaseOrgPrincipal, authentication_evidence_class: RpBaseOrgSessionAuthenticationEvidence,
  ).freeze
  TECH_ORG = Profile.new(
    cell: RpCellBinding.fetch("rp_tech_org"), namespace: "BASE_ORG", resource_type: "operator",
    record_class: RpTechOrgRecord, session_class: RpTechOrgSession,
    binding_class: RpTechOrgOpSessionBinding, identity_binding_class: RpTechOrgIdentityBinding,
    principal_class: RpTechOrgPrincipal, authentication_evidence_class: nil,
  ).freeze

  BY_CLIENT_ID = [APP, ORG, TECH_ORG].index_by { |profile| profile.cell.client_id }.freeze
  BY_SESSION_CLASS = [APP, ORG, TECH_ORG].index_by { |profile| profile.session_class }.freeze

  class << self
    public

    def for_client_id(client_id) = BY_CLIENT_ID.fetch(client_id.to_s)

    def for_session(session)
      BY_SESSION_CLASS.fetch(session.class) do
        raise ArgumentError, "unsupported RP session for Base API authority: #{session.class.name}"
      end
    end

    def audience_for(resource_type)
      Rails.configuration.x.boot_config.fetch(:hosts).base_for_resource_type(resource_type).to_s
    end

    def issuer_for(profile) = JitSecurityJwtRegistry.surface(profile.namespace).issuer

    def key_issuer_id_for(profile) = "surface:#{profile.namespace}"

    def op_issuer?(profile, issuer)
      hosts = Rails.configuration.x.boot_config.fetch(:hosts)
      configured_host =
        case profile.resource_type
        when "client" then hosts.visa_service
        when "operator" then hosts.visa_staff
        else raise ArgumentError, "unsupported RP resource type: #{profile.resource_type.inspect}"
        end
      configured_origin = Oidc::AcmeServiceOrigin.from_configured_host(
        configured_host&.host, default_scheme: "https",
      )
      allowed_origins = [configured_origin.origin]
      if configured_origin.host.end_with?(".localhost")
        local_http_origin = URI::HTTP.build(
          scheme: "http", host: configured_origin.host, port: configured_origin.port,
        ).to_s
        allowed_origins << Oidc::AcmeServiceOrigin.from(local_http_origin, default_scheme: "http").origin
      end
      allowed_origins.include?(issuer)
    end
  end
end
