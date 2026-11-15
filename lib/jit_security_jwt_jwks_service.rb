# typed: false
# frozen_string_literal: true

require "jit_security_jwt_registry"

module JitSecurityJwtJwksService
  module_function

  def jwk_set(namespace = nil)
    return JitSecurityJwtRegistry.jwks_for("auth") if namespace.blank?

    JitSecurityJwtRegistry.jwks_for("surface:#{JitSecurityJwtRegistry.normalize_namespace(namespace)}")
  end
end
