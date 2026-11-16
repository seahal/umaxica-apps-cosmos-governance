# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch30LibEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JitSecurityJwtJwk normalize_public and validate_public arms" do
    rsa_key = OpenSSL::PKey::RSA.generate(3072)
    public_jwk = JWT::JWK.new(rsa_key, kid: "coverage-key").export.stringify_keys.except(
      *JitSecurityJwtJwk::PRIVATE_FIELDS,
    ).merge("alg" => "PS256", "use" => "sig")

    assert_equal "coverage-key", JitSecurityJwtJwk.normalize_public(public_jwk).fetch("kid")
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public([]) }
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.normalize_public(public_jwk.merge("d" => "private"))
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(public_jwk.except("n"))
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(public_jwk.merge("kty" => "EC"))
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(public_jwk.merge("alg" => "RS256"))
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(public_jwk.merge("use" => "enc"))
    end
  end
end
