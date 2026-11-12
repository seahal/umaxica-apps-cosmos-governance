# typed: false
# frozen_string_literal: true

# Facade over `AuthenticationTokenService` for the decode and claim-extraction operations
# used by the current RP credential boundary.
class AuthenticationToken
  JWT_ALGORITHM = "ES384"

  class << self
    def decode(token, host:, resource_type: nil, issuer: nil, audiences: nil, jwt_issuer_id: nil)
      AuthenticationTokenService.decode(
        token, host: host, resource_type: resource_type, issuer: issuer,
               audiences: audiences, jwt_issuer_id: jwt_issuer_id,
      )
    end

    def extract_subject(payload)
      AuthenticationTokenService.extract_subject(payload)
    end

    def extract_resource_type(payload)
      AuthenticationTokenService.extract_resource_type(payload)
    end

    def resource_type_scope_matches?(payload, expected_resource_type)
      AuthenticationTokenService.resource_type_scope_matches?(payload, expected_resource_type)
    end

    def extract_session_id(payload)
      AuthenticationTokenService.extract_session_id(payload)
    end

    def extract_session_id_allow_expired(token, host:, resource_type: nil, issuer: nil, audiences: nil,
                                         jwt_issuer_id: nil)
      AuthenticationTokenService.extract_session_id_allow_expired(
        token,
        host: host,
        resource_type: resource_type,
        issuer: issuer,
        audiences: audiences,
        jwt_issuer_id: jwt_issuer_id,
      )
    end

    def extract_jti(payload)
      AuthenticationTokenService.extract_jti(payload)
    end
  end
end
