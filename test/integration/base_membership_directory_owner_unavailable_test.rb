# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseMembershipDirectoryOwnerUnavailableTest < ActionDispatch::IntegrationTest
  test "APP and ORG membership directory routes refuse unavailable Access authority" do
    endpoints = [
      ["PUBLIC_BASE_SERVICE_URL", "app"],
      ["PUBLIC_BASE_STAFF_URL", "org"],
    ]

    endpoints.each do |host_variable, realm|
      host! ENV.fetch(host_variable)
      paths = [
        [:get, "/api/v0/membership/#{realm}/accounts"],
        [:get, "/api/v0/membership/#{realm}/accounts/external-account"],
        [:get, "/api/v0/membership/#{realm}/organizations"],
        [:get, "/api/v0/membership/#{realm}/organizations/external-organization"],
        [:get, "/api/v0/membership/#{realm}/organizations/external-organization/memberships"],
        [:get, "/api/v0/membership/#{realm}/organizations/external-organization/memberships/1"],
        [:post, "/api/v0/membership/#{realm}/organizations/external-organization/memberships/authorization"],
      ]

      OidcClientRegistry.stub(:authenticate_assertion, true) do
        paths.each do |method, path|
          public_send(
            method,
            path,
            headers: {
              "X-Client-Assertion" => "authenticated-client",
              "Authorization" => "Bearer external-proof",
            },
          )

          assert_response :service_unavailable, "#{method.upcase} #{path} on #{realm}"
          assert_equal "application/problem+json", response.media_type
          assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
          assert_equal 503, response.parsed_body.fetch("status")
          assert_equal "no-store", response.headers["Cache-Control"]
          assert_nil response.location
          assert_not_includes response.body, '"accounts":[]'
        end
      end
    end
  end
end
