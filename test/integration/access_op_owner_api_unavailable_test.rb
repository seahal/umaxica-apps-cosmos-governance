# frozen_string_literal: true

require "test_helper"

class AccessOpOwnerApiUnavailableTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Avatar owner APIs reject untrusted callers and explicitly refuse unavailable OP authority in both realms" do
    { "app" => "PUBLIC_BASE_SERVICE_URL", "org" => "PUBLIC_BASE_STAFF_URL" }.each do |surface, host_key|
      host! ENV.fetch(host_key)
      path = "/api/v0/avatar/#{surface}/switcher"

      OidcClientRegistry.stub(:authenticate_assertion, false) do
        get path, headers: { "X-Client-Assertion" => "invalid", "Authorization" => "Bearer external-proof" }

        assert_response :unauthorized
        assert_equal({ "error" => "invalid_client" }, response.parsed_body)
        assert_equal "no-store", response.headers["Cache-Control"]
      end

      OidcClientRegistry.stub(:authenticate_assertion, true) do
        get path,
            headers: { "X-Client-Assertion" => "authenticated-client", "Authorization" => "Bearer external-proof" }

        assert_response :service_unavailable
        assert_equal "application/problem+json", response.media_type
        assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
        assert_equal 503, response.parsed_body.fetch("status")
        assert_equal "no-store", response.headers["Cache-Control"]
        assert_nil response.location
      end
    end
  end

  test "Tech capability API reports missing Access authority instead of a successful denial" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")

    OidcClientRegistry.stub(:authenticate_assertion, true) do
      post "/api/v0/tech-capability-checks",
           params: { access_token: "external-proof", client_assertion: "client-proof" }

      assert_response :service_unavailable
      assert_equal "application/problem+json", response.media_type
      assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
      assert_equal 503, response.parsed_body.fetch("status")
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_nil response.location
    end
  end
end
