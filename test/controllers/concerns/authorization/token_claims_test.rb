# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Authorization
  class TokenClaimsTest < ActiveSupport::TestCase
    test "extractors preserve external subject session Base binding and token identity separately" do
      payload = {
        "sub" => "external-subject",
        "scope" => "authenticated domain:client",
        "sid" => "rp-session-public-id",
        "umx_base_sid" => "base-session-public-id",
        "jti" => "external-token-id",
        "aud" => ["governance"],
        "client_id" => "base-app-ww",
      }

      assert_equal "external-subject", AuthorizationTokenClaims.subject(payload)
      assert_equal "client", AuthorizationTokenClaims.resource_type(payload)
      assert_equal "rp-session-public-id", AuthorizationTokenClaims.session_id(payload)
      assert_equal "base-session-public-id", AuthorizationTokenClaims.base_session_id(payload)
      assert_equal "external-token-id", AuthorizationTokenClaims.jti(payload)
      assert_equal %w(authenticated domain:client), AuthorizationTokenClaims.scopes(payload)
      assert_equal ["governance"], AuthorizationTokenClaims.audiences(payload)
      assert_equal "base-app-ww", AuthorizationTokenClaims.client_id(payload)
    end

    test "extractors return nil when payload is nil" do
      assert_nil AuthorizationTokenClaims.subject(nil)
      assert_nil AuthorizationTokenClaims.resource_type(nil)
      assert_nil AuthorizationTokenClaims.session_id(nil)
      assert_nil AuthorizationTokenClaims.base_session_id(nil)
      assert_nil AuthorizationTokenClaims.jti(nil)
    end
  end
end
