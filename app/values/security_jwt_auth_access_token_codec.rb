# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

require "jwt"

class SecurityJwtAuthAccessTokenCodec
  JWT_ALGORITHM = SecurityJwtRfc9068AccessTokenProfile::ALGORITHM
  TOKEN_TYPE = SecurityJwtRfc9068AccessTokenProfile::TOKEN_TYPE
  VALID_RESOURCE_TYPES = %w(client operator).freeze
  # Keyring used when a caller does not name one. Callers that sign or verify
  # with a surface keyring must pass `jwt_issuer_id:` explicitly; the keyring is
  # never inferred from the request host.
  DEFAULT_JWT_ISSUER_ID = "auth"

  class << self
    def decode(token, host:, resource_type: nil, issuer: nil, audiences: nil, jwt_issuer_id: nil)
      decode_with_expiration(
        token, host: host, resource_type: resource_type, issuer: issuer,
               audiences: audiences, verify_exp: true, jwt_issuer_id: jwt_issuer_id,
      )
    end

    def decode_allow_expired(token, host:, resource_type: nil, issuer: nil, audiences: nil, jwt_issuer_id: nil)
      decode_with_expiration(
        token, host: host, resource_type: resource_type, issuer: issuer,
               audiences: audiences, verify_exp: false, jwt_issuer_id: jwt_issuer_id,
      )
    end

    def extract_session_id_allow_expired(token, host:, resource_type: nil, issuer: nil, audiences: nil,
                                         jwt_issuer_id: nil)
      payload = decode_allow_expired(
        token, host: host, resource_type: resource_type,
               issuer: issuer, audiences: audiences, jwt_issuer_id: jwt_issuer_id,
      )
      AuthorizationTokenClaims.session_id(payload) if payload.present?
    end

    def decode_with_expiration(token, host:, resource_type: nil, issuer: nil, audiences: nil, verify_exp:,
                               jwt_issuer_id: nil)
      return nil if token.blank? || host.blank?

      header = JitSecurityJwtKeyring.parse_header(token)
      unless valid_header?(header)
        report_invalid_header(resource_type: resource_type, host: host, header: header)
        return nil
      end

      public_key = JitSecurityJwtKeyring.public_key_for(header["kid"], issuer_id: resolve_jwt_issuer_id(jwt_issuer_id))
      if public_key.nil?
        JitSecurityJwtAnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: "UNKNOWN_KID",
        )
        return nil
      end

      payload, = JWT.decode(
        token, public_key, true,
        decode_options(resource_type, issuer, audiences, verify_exp: verify_exp),
      )
      unless SecurityJwtRfc9068AccessTokenProfile.claims_structurally_valid?(payload)
        JitSecurityJwtAnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          payload: payload,
          reason: "CLAIM_INVALID",
        )
        return nil
      end

      payload
    rescue JWT::ExpiredSignature
      return nil unless verify_exp

      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: resource_type,
        host: host,
        header: header,
        reason: "EXPIRED",
      )
      Rails.logger.info(JitLogEvent.format("authentication.token.verification.expired", host: host))
      nil
    rescue JWT::InvalidIssuerError, JWT::InvalidAudError, JWT::InvalidIatError, JWT::ImmatureSignature => e
      report_claim_error(resource_type: resource_type, host: host, header: header, error: e)
      Rails.logger.info(
        JitLogEvent.format(
          "authentication.token.verification.claim_invalid",
          error_class: e.class.name,
          host: host,
        ),
      )
      nil
    rescue JWT::DecodeError, JWT::VerificationError => e
      report_decode_error(resource_type: resource_type, host: host, header: header, error: e)
      Rails.logger.info(
        JitLogEvent.format(
          "authentication.token.verification.failed",
          error_class: e.class.name,
          host: host,
        ),
      )
      nil
    rescue OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
      Rails.logger.info(
        JitLogEvent.format(
          "authentication.token.verification.error",
          error_class: e.class.name,
          error_message: e.message,
          host: host,
        ),
      )
      nil
    end

    def extract_subject(payload)
      AuthorizationTokenClaims.subject(payload)
    end

    def extract_resource_type(payload)
      AuthorizationTokenClaims.resource_type(payload)
    end

    def extract_session_id(payload)
      AuthorizationTokenClaims.session_id(payload)
    end

    def extract_jti(payload)
      AuthorizationTokenClaims.jti(payload)
    end

    # The resource type is carried by exactly one `domain:<type>` scope value,
    # not by the RFC 8693 `act` claim.
    def resource_type_scope_matches?(payload, expected_resource_type)
      return false if payload.blank?

      resource_type = extract_resource_type(payload)
      return false unless VALID_RESOURCE_TYPES.include?(resource_type)

      resource_type == expected_resource_type.to_s
    end

    def extract_scopes(payload)
      AuthorizationTokenClaims.scopes(payload)
    end

    def has_scope?(payload, scope)
      scopes = extract_scopes(payload)
      scopes.include?(scope.to_s)
    end

    private

    def resolve_jwt_issuer_id(jwt_issuer_id)
      jwt_issuer_id.presence || DEFAULT_JWT_ISSUER_ID
    end

    def decode_options(resource_type, issuer, audiences, verify_exp:)
      {
        algorithms: [JWT_ALGORITHM],
        required_claims: %w(iss aud exp nbf iat sub sid client_id jti acr scope),
        leeway: AuthenticationJwtConfiguration.leeway_seconds,
        verify_iat: { leeway: AuthenticationJwtConfiguration.leeway_seconds },
        verify_expiration: verify_exp,
        verify_not_before: true,
        verify_iss: true,
        iss: issuer || AuthenticationJwtConfiguration.issuer,
        verify_aud: true,
        aud: audiences || AuthenticationJwtConfiguration.audiences(resource_type),
      }
    end

    def valid_header?(header)
      SecurityJwtRfc9068AccessTokenProfile.header_valid?(header)
    end

    def report_invalid_header(resource_type:, host:, header:)
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: resource_type,
        host: host,
        header: header,
        reason: SecurityJwtRfc9068AccessTokenProfile.header_rejection_reason(header),
      )
    end

    def report_claim_error(resource_type:, host:, header:, error:)
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: resource_type,
        host: host,
        header: header,
        reason: "CLAIM_INVALID",
        error: error,
      )
    end

    def report_decode_error(resource_type:, host:, header:, error:)
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: resource_type,
        host: host,
        header: header,
        reason: "DECODE_FAILED",
        error: error,
      )
    end
  end
end

# rubocop:enable Metrics/MethodLength
