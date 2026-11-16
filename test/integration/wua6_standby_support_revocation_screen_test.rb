# frozen_string_literal: true

require "test_helper"

class Wua6StandbySupportRevocationScreenTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "ORG owner APIs reject an external proof in place of Governance authority" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    ["/api/v0/support/app/accounts/external-subject/revocation-screen", "/api/v0/iam/grant-screen"].each do |path|
      OidcClientRegistry.stub(:authenticate_assertion, true) do
        get path, headers: { "X-Client-Assertion" => "client-proof", "Authorization" => "Bearer external-proof" }
      end

      assert_response :unauthorized
      assert_equal "application/json", response.media_type
      assert_equal "invalid_token", response.parsed_body.fetch("error")
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_nil response.location
    end
  end
end
