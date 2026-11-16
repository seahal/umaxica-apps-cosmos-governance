# frozen_string_literal: true

require "test_helper"

class OidcIssuerRetiredEndpointsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "retired OP endpoints fail explicitly for both resource types" do
    %w(client operator).each do |resource_type|
      assert_raises(OidcIssuer::UnavailableError) { OidcIssuer.authorization_endpoint(resource_type) }
      assert_raises(OidcIssuer::UnavailableError) { OidcIssuer.token_endpoint(resource_type) }
      assert_raises(OidcIssuer::UnavailableError) { OidcIssuer.userinfo_endpoint(resource_type) }
      assert_raises(OidcIssuer::UnavailableError) { OidcIssuer.revocation_endpoint(resource_type) }
      assert_raises(OidcIssuer::UnavailableError) { OidcIssuer.end_session_endpoint(resource_type) }
    end
  end
end
