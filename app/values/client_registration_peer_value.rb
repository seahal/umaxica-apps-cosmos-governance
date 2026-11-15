# typed: false
# frozen_string_literal: true

# Origins and the one Auth answer path used by the registration handoffs
# (docs/pending-registration-routes-contract.md). The Auth answer path is Access's to confirm.
module ClientRegistrationPeerValue
  module_function

  ANSWER_PATH = "/sign/up/answer"
  TOKEN_PARAMETER = "h"
  JWKS_PATH = "/.well-known/jwks.json"

  def auth_origin
    Rails.configuration.x.boot_config.fetch(:hosts).auth_service.to_s
  end

  def auth_jwks_uri
    "#{auth_origin}#{JWKS_PATH}"
  end

  def base_origin
    JumpRtSurface.issuer_origin("BASE_APP")
  end

  def answer_url(token)
    "#{auth_origin}#{ANSWER_PATH}?#{TOKEN_PARAMETER}=#{token}"
  end
end
