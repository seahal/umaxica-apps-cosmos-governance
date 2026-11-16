# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseMembershipDirectoryOwnerUnavailableTest < ActionDispatch::IntegrationTest
  test "APP and ORG membership owner routes reject an Access credential in place of Governance authority" do
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

          assert_response :unauthorized, "#{method.upcase} #{path} on #{realm}"
          assert_equal "application/json", response.media_type
          assert_equal "invalid_token", response.parsed_body.fetch("error")
          assert_equal "no-store", response.headers["Cache-Control"]
          assert_nil response.location
        end
      end
    end
  end
end
