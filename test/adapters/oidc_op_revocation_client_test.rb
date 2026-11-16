# frozen_string_literal: true

require "test_helper"

class OidcOpRevocationClientTest < ActiveSupport::TestCase
  UnsupportedClient = Data.define(:client_id, :resource_type, :registered_token_endpoint_auth_method)
  APP_CLIENT_ID = RpCellBinding.fetch("rp_base_app").client_id

  test "Base App refresh revocation uses the exact Visa endpoint and private_key_jwt form body" do
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
    )
    endpoint = URI.parse(OutboundHttp::LocalBackChannel.url(visa_origin.revocation_endpoint))
    captured_body = nil
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(endpoint.to_s) do |request|
          captured_body = URI.decode_www_form(request.body).to_h
          [200, { "Content-Type" => "application/json" }, "{}"]
        end
      end

    OidcClientAssertionJwt.stub(
      :issue, ->(client_id:, token_url:) {
        assert_equal "base-app-ww", client_id
        assert_equal visa_origin.revocation_endpoint, token_url
        "test-client-assertion"
      },
    ) do
      stub_outbound_http(stubs) do
        result = OidcOpRevocationClient.revoke(
          token: "bound-refresh-token", client_id: APP_CLIENT_ID, origin: visa_origin,
        )

        assert_predicate result, :success?
      end
    end
    stubs.verify_stubbed_calls

    assert_equal(
      %w(client_assertion client_assertion_type client_id token token_type_hint),
      captured_body.keys.sort,
    )
    assert_equal "base-app-ww", captured_body.fetch("client_id")
    assert_equal OidcClientAssertionJwt::ASSERTION_TYPE, captured_body.fetch("client_assertion_type")
    assert_equal "test-client-assertion", captured_body.fetch("client_assertion")
    assert_equal "bound-refresh-token", captured_body.fetch("token")
    assert_equal "refresh_token", captured_body.fetch("token_type_hint")
    assert_nil captured_body["client_secret"]
  end

  test "an HTTP rejection does not retry the Refresh Token request" do
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
    )
    endpoint = URI.parse(OutboundHttp::LocalBackChannel.url(visa_origin.revocation_endpoint))
    calls = 0
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(endpoint.to_s) do |_request|
          calls += 1
          [400, { "Content-Type" => "application/json" }, "{}"]
        end
      end

    OidcClientAssertionJwt.stub(:issue, ->(**) { "test-client-assertion" }) do
      stub_outbound_http(stubs) do
        result = OidcOpRevocationClient.revoke(
          token: "bound-refresh-token", client_id: APP_CLIENT_ID, origin: visa_origin,
        )

        assert_equal :rejected, result.outcome
      end
    end
    stubs.verify_stubbed_calls

    assert_equal 1, calls
  end

  test "a transient network failure retries once with a fresh client assertion" do
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
    )
    endpoint = URI.parse(OutboundHttp::LocalBackChannel.url(visa_origin.revocation_endpoint))
    request_assertions = []
    calls = 0
    stubs =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(endpoint.to_s) do |request|
          calls += 1
          request_assertions << URI.decode_www_form(request.body).to_h.fetch("client_assertion")
          raise Faraday::ConnectionFailed, "transient test failure" if calls == 1

          [200, { "Content-Type" => "application/json" }, "{}"]
        end
      end
    assertion_number = 0
    assertion_issuer =
      lambda do |client_id:, token_url:|
        assert_equal "base-app-ww", client_id
        assert_equal visa_origin.revocation_endpoint, token_url
        assertion_number += 1
        "test-client-assertion-#{assertion_number}"
      end

    OidcClientAssertionJwt.stub(:issue, assertion_issuer) do
      stub_outbound_http(stubs) do
        result = OidcOpRevocationClient.revoke(
          token: "bound-refresh-token", client_id: APP_CLIENT_ID, origin: visa_origin,
        )

        assert_predicate result, :success?
      end
    end
    stubs.verify_stubbed_calls

    assert_equal 2, calls
    assert_equal ["test-client-assertion-1", "test-client-assertion-2"], request_assertions
  end

  test "an unregistered token endpoint authentication method raises" do
    client = UnsupportedClient.new(
      client_id: "base-app-ww", resource_type: "client", registered_token_endpoint_auth_method: "none",
    )

    OidcClientRegistry.stub(:find!, client) do
      assert_raises(OidcOpRevocationClient::UnsupportedAuthenticationMethod) do
        OidcOpRevocationClient.revoke(
          token: "bound-refresh-token", client_id: APP_CLIENT_ID,
          origin: Oidc::AcmeServiceOrigin.from_configured_host(
            Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host, default_scheme: "https",
          ),
        )
      end
    end
  end
end
