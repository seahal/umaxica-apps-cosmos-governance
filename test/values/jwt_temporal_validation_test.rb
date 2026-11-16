# typed: false
# frozen_string_literal: true

require "test_helper"

class JwtTemporalValidationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "auth access enforces the fixed thirty second iat nbf and exp boundaries" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      payload = {
        "iss" => AuthenticationJwtConfiguration.issuer,
        "aud" => AuthenticationJwtConfiguration.audiences("client"),
        "exp" => now + 300,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "client_id" => AuthenticationJwtConfiguration.client_id("client"),
        "jti" => "temporal-jti",
        "acr" => "aal1",
        "scope" => "openid domain:client",
      }
      cases = [
        ["iat", now + 29, true], ["iat", now + 30, true], ["iat", now + 31, false],
        ["nbf", now + 29, true], ["nbf", now + 30, true], ["nbf", now + 31, false],
        ["exp", now - 29, true], ["exp", now - 30, false], ["exp", now - 31, false],
      ]
      cases.each do |claim, value, accepted|
        token = JitSecurityJwtKeyring.encode(payload.merge(claim => value), typ: "at+jwt", issuer_id: "auth")
        result = SecurityJwtAuthAccessTokenCodec.decode(token, host: "audit.example", resource_type: "client")

        assert_equal accepted, result.present?, "#{claim}=#{value - now}"
      end
    end
  end

  test "expired access decoding relaxes only expiration and preserves signature issuer audience and nbf checks" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      payload = {
        "iss" => AuthenticationJwtConfiguration.issuer,
        "aud" => AuthenticationJwtConfiguration.audiences("client"),
        "exp" => now + 300,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "client_id" => AuthenticationJwtConfiguration.client_id("client"),
        "jti" => "temporal-jti",
        "acr" => "aal1",
        "scope" => "openid domain:client",
      }
      payload["exp"] = now - 120
      payload["iat"] = payload["nbf"] = now - 180
      token = JitSecurityJwtKeyring.encode(payload, typ: "at+jwt", issuer_id: "auth")

      assert_nil SecurityJwtAuthAccessTokenCodec.decode(token, host: "audit.example", resource_type: "client")
      assert_equal payload, SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
        token, host: "audit.example", resource_type: "client",
      )

      [
        payload.merge("iss" => "urn:other:auth"),
        payload.merge("aud" => ["other-audience"]),
        payload.merge("nbf" => now + 31),
        payload.merge("iat" => now + 31),
        payload.except("exp"),
      ].each do |invalid_payload|
        invalid = JitSecurityJwtKeyring.encode(invalid_payload, typ: "at+jwt", issuer_id: "auth")

        assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
          invalid, host: "audit.example", resource_type: "client",
        )
      end

      forged = JWT.encode(
        payload, OpenSSL::PKey::RSA.generate(3072), "PS256",
        { typ: "at+jwt", kid: JitSecurityJwtKeyring.active_kid("auth") },
      )

      assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
        forged, host: "audit.example", resource_type: "client",
      )
    end
  end

  test "anonymous preference JWT uses the exact 400 day lifetime without nbf" do
    travel_to Time.utc(2026, 10, 22, 12) do
      host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
      issued_at = Time.current
      snapshot = SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first)
      token = PreferenceToken.encode(
        snapshot, host: host, preference_type: "AppPreference",
                  public_id: "temporal-preference", jti: "temporal-jti",
                  jwt_issuer_id: "preference_app", issued_at: issued_at,
      )

      payload, header = JWT.decode(token, nil, false)

      assert_equal issued_at.to_i, payload.fetch("iat")
      assert_equal issued_at.to_i + 400.days.to_i, payload.fetch("exp")
      assert_equal "app", payload.fetch("aud")
      assert_equal "JWT", header.fetch("typ")
      assert_not payload.key?("nbf")
      assert_predicate PreferenceToken.decode(token, host: host, jwt_issuer_id: "preference_app"), :present?
    end
  end

  test "separated RP access verification enforces the fixed thirty second iat nbf and exp boundaries" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      issuer = "https://base.example/app"
      key = OpenSSL::PKey::RSA.generate(3072)
      jwk = JitSecurityJwtJwk.export_public(key, kid: "temporal-key")
      jwks_client = OidcOpJwksClient.new(
        jwks_uri: "https://base.example/.well-known/jwks.json",
        fetcher: -> { { "keys" => [jwk] } },
      )
      payload = {
        "iss" => issuer,
        "aud" => ["base-app-ww"],
        "exp" => now + 240,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "jti" => "temporal-jti",
        "client_id" => "base-app-ww",
        "scope" => "openid",
        "authn_ctx" => "normal",
      }
      cases = [
        ["iat", now + 29, true], ["iat", now + 30, true], ["iat", now + 31, false],
        ["nbf", now + 29, true], ["nbf", now + 30, true], ["nbf", now + 31, false],
        ["exp", now - 29, true], ["exp", now - 30, false], ["exp", now - 31, false],
      ]
      cases.each do |claim, value, accepted|
        token = JWT.encode(payload.merge(claim => value), key, "PS256", { typ: "at+jwt", kid: "temporal-key" })
        result = OidcOpAccessTokenVerifier.new(
          access_token: token, client_id: "base-app-ww", realm: "app", issuer: issuer,
          audience: "base-app-ww", jwks_client: jwks_client,
        ).call

        assert_equal accepted, result.success?, "#{claim}=#{value - now}"
      end
    end
  end

  test "Access RP token verification accepts PS256 and rejects ES384 RS256 PS384 and none" do
    now = Time.current.to_i
    issuer = "https://auth.example.invalid"
    client_id = "base-app-ww"
    key = OpenSSL::PKey::RSA.generate(3072)
    kid = "access-rp-algorithm-test"
    jwks_client = OidcOpJwksClient.new(
      jwks_uri: "https://auth.example.invalid/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: kid)] } },
    )
    payload = {
      "iss" => issuer,
      "aud" => [client_id],
      "exp" => now + 300,
      "iat" => now,
      "nbf" => now,
      "sub" => "rp-subject",
      "sid" => "rp-session",
      "jti" => "rp-jti",
      "client_id" => client_id,
      "scope" => "openid",
      "authn_ctx" => "normal",
    }
    sign =
      lambda do |algorithm, signing_key|
        JWT.encode(payload, signing_key, algorithm, { typ: "at+jwt", kid: kid, alg: algorithm })
      end
    accepted = OidcOpAccessTokenVerifier.new(
      access_token: sign.call("PS256", key), client_id:, realm: "app", issuer:, audience: client_id,
      jwks_client:,
    ).call

    assert_predicate accepted, :success?
    [
      ["ES384", OpenSSL::PKey::EC.generate("secp384r1")],
      ["RS256", key],
      ["PS384", key],
      ["none", nil],
    ].each do |algorithm, signing_key|
      result = OidcOpAccessTokenVerifier.new(
        access_token: sign.call(algorithm, signing_key), client_id:, realm: "app", issuer:,
        audience: client_id, jwks_client:,
      ).call

      assert_not_predicate result, :success?, "#{algorithm} must be refused"
      assert_equal "invalid_header", result.error, algorithm
    end
  end

  test "Access RP token verification rejects RSA 2048 and accepts RSA 3072 and 4096 OP keys" do
    now = Time.current.to_i
    issuer = "https://auth-key-size.example.invalid"
    client_id = "base-app-ww"
    payload = {
      "iss" => issuer,
      "aud" => [client_id],
      "exp" => now + 300,
      "iat" => now,
      "nbf" => now,
      "sub" => "rp-subject",
      "sid" => "rp-session",
      "jti" => "rp-jti",
      "client_id" => client_id,
      "scope" => "openid",
      "authn_ctx" => "normal",
    }

    [
      [2_048, false],
      [3_072, true],
      [4_096, true],
    ].each do |bits, accepted|
      key = OpenSSL::PKey::RSA.generate(bits)
      kid = "access-rp-rsa-#{bits}"
      jwk =
        if bits < JitSecurityJwtJwk::MIN_RSA_MODULUS_BITS
          JWT::JWK.new(key, kid: kid).export.stringify_keys.except(
            *JitSecurityJwtJwk::PRIVATE_FIELDS,
          ).merge("alg" => "PS256", "use" => "sig")
        else
          JitSecurityJwtJwk.export_public(key, kid: kid)
        end
      token = JWT.encode(payload, key, "PS256", { typ: "at+jwt", kid: kid })
      jwks_client = OidcOpJwksClient.new(
        jwks_uri: "#{issuer}/#{bits}/.well-known/jwks.json",
        fetcher: -> { { "keys" => [jwk] } },
      )

      result = OidcOpAccessTokenVerifier.new(
        access_token: token, client_id:, realm: "app", issuer:, audience: client_id, jwks_client:,
      ).call

      assert_equal accepted, result.success?, "RSA #{bits} must be #{accepted ? "accepted" : "refused"}"
      assert_equal "key_unavailable", result.error if bits == 2_048
    end
  end

  test "Access RP token verification binds type audience header algorithm and signature" do
    now = Time.current.to_i
    issuer = "https://auth-token-contract.example.invalid"
    client_id = "base-app-ww"
    key = OpenSSL::PKey::RSA.generate(3_072)
    kid = "access-rp-token-contract"
    jwks_client = OidcOpJwksClient.new(
      jwks_uri: "#{issuer}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: kid)] } },
    )
    payload = {
      "iss" => issuer,
      "aud" => [client_id],
      "exp" => now + 300,
      "iat" => now,
      "nbf" => now,
      "sub" => "rp-subject",
      "sid" => "rp-session",
      "jti" => "rp-jti",
      "client_id" => client_id,
      "scope" => "openid",
      "authn_ctx" => "normal",
    }
    valid = JWT.encode(payload, key, "PS256", { typ: "at+jwt", kid: kid })

    assert_predicate OidcOpAccessTokenVerifier.new(
      access_token: valid, client_id:, realm: "app", issuer:, audience: client_id, jwks_client:,
    ).call, :success?

    wrong_type = JWT.encode(payload, key, "PS256", { typ: "JWT", kid: kid })
    wrong_audience = JWT.encode(payload.merge("aud" => ["another-client"]), key, "PS256", { typ: "at+jwt", kid: kid })
    mismatch_parts = valid.split(".")
    mismatch_header = JSON.parse(Base64.urlsafe_decode64(mismatch_parts.first))
    mismatch_parts[0] = Base64.urlsafe_encode64(mismatch_header.merge("alg" => "RS256").to_json, padding: false)
    tampered_parts = valid.split(".")
    tampered_payload = JSON.parse(Base64.urlsafe_decode64(tampered_parts.second))
    tampered_parts[1] = Base64.urlsafe_encode64(
      JSON.generate(tampered_payload.merge("scope" => "openid profile")), padding: false,
    )

    [
      ["wrong type", wrong_type],
      ["wrong audience", wrong_audience],
      ["PS256 signature with RS256 header", mismatch_parts.join(".")],
      ["tampered payload", tampered_parts.join(".")],
    ].each do |label, token|
      result = OidcOpAccessTokenVerifier.new(
        access_token: token, client_id:, realm: "app", issuer:, audience: client_id, jwks_client:,
      ).call

      assert_not_predicate result, :success?, "#{label} must be refused"
    end
  end
end
