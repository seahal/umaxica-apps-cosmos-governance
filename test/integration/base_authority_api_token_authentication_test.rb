# frozen_string_literal: true

require "test_helper"

class BaseAuthorityApiTokenAuthenticationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Avatar owner APIs require a Governance bearer for each fixed realm" do
    { "app" => "PUBLIC_BASE_SERVICE_URL", "org" => "PUBLIC_BASE_STAFF_URL" }.each do |surface, host_key|
      host! ENV.fetch(host_key)
      path = "/api/v0/avatar/#{surface}/switcher"

      [{}, { "Authorization" => "Bearer invalid" }, { "Authorization" => "Basic credentials" }].each do |headers|
        get path, headers: headers

        assert_response :unauthorized
        assert_equal({ "error" => "invalid_token" }, response.parsed_body)
        assert_equal "no-store", response.headers["Cache-Control"]
      end
    end
  end

  test "Tech capability API refuses a bearer that is not a verified active Tech RP session" do
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")

    [{}, { "Authorization" => "Bearer invalid" }, { "Authorization" => "Basic credentials" }].each do |headers|
      post "/api/v0/tech-capability-checks", headers: headers

      assert_response :unauthorized
      assert_equal({ "error" => "invalid_token" }, response.parsed_body)
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end
end
