# typed: false
# frozen_string_literal: true

module AuthorizationTokenClaims
  module_function

  def subject(payload)
    payload&.dig("sub")
  end

  def resource_type(payload)
    SecurityJwtRfc9068AccessTokenProfile.resource_type_from_scope(payload)
  end

  def session_id(payload)
    payload&.dig("sid")
  end

  def base_session_id(payload)
    payload&.dig("umx_base_sid")
  end

  def jti(payload)
    payload&.dig("jti")
  end

  def scopes(payload)
    SecurityJwtRfc9068AccessTokenProfile.parse_scopes(payload)
  end

  # The trusted authentication context of a decoded access token. A payload
  # with no claim is a session minted before Emergency Access existed, which
  # was Normal; an unrecognised value resolves to the capability-less UNKNOWN
  # context rather than to Normal.
  def authentication_context(payload)
    AuthenticationContextValue.from_claims(payload)
  end

  def audiences(payload)
    payload&.dig("aud") || []
  end

  def client_id(payload)
    payload&.dig("client_id")
  end
end
