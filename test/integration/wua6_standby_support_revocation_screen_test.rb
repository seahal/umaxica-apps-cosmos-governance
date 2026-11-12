# frozen_string_literal: true

require "test_helper"

class Wua6StandbySupportRevocationScreenTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "ORG owner screens expose unavailable session authority without returning protected account data" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    ["/api/v0/support/app/accounts/external-subject/revocation-screen", "/api/v0/iam/grant-screen"].each do |path|
      OidcClientRegistry.stub(:authenticate_assertion, true) do
        get path, headers: { "X-Client-Assertion" => "client-proof", "Authorization" => "Bearer external-proof" }
      end

      assert_response :service_unavailable
      assert_equal "application/problem+json", response.media_type
      assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
      assert_equal 503, response.parsed_body.fetch("status")
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_nil response.location
    end
  end
end
