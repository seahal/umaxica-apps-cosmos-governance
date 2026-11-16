# frozen_string_literal: true

require "test_helper"

class BaseOrgIamOwnerApiTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "IAM writes reject an invalid Governance bearer without granting capability or committing audit intent" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    OidcClientRegistry.stub(:authenticate_assertion, true) do
      assert_no_difference [
        "OperatorCapabilityGrant.count", "OrgIamOperationOutcome.count", "Chronicle.count",
      ] do
        post "/api/v0/iam/grants", params: { operator_public_id: "external-subject", capability: "tech.access" },
                                   headers: {
                                     "X-Client-Assertion" => "client-proof", "Authorization" => "Bearer external-proof",
                                   }
      end

      assert_response :unauthorized
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_nil response.location
    end
  end
end
