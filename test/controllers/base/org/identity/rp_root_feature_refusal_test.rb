# frozen_string_literal: true

require "test_helper"

class BaseOrgIdentityRpRootFeatureRefusalTest < ActionDispatch::IntegrationTest
  test "local ORG RP proof does not grant root credential management authority" do
    operator = operators(:one)
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    original_credentials = operator.staff_secret_credentials.count

    as_rp_cell("base-org-ww") do
      headers = as_staff_headers(operator, host:)
      get "/identity/secrets", params: { ri: "jp" }, headers: headers

      assert_response :service_unavailable
      assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
      assert_includes response.headers["Cache-Control"], "no-store"
      post "/identity/secrets/nonexistent/removal", params: { ri: "jp" }, headers: headers

      assert_response :service_unavailable
      assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
      assert_includes response.headers["Cache-Control"], "no-store"

      [
        [:get, "/identity/secrets/new"],
        [:get, "/identity/secrets/nonexistent"],
        [:get, "/identity/secrets/nonexistent/edit"],
        [:post, "/identity/secrets"],
        [:patch, "/identity/secrets/nonexistent"],
        [:delete, "/identity/secrets/nonexistent"],
      ].each do |method, path|
        process(method, path, params: { ri: "jp" }, headers: headers)

        assert_response :service_unavailable, "#{method.upcase} #{path} must fail closed"
        assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
        assert_includes response.headers["Cache-Control"], "no-store"
      end
    end

    assert_equal original_credentials, operator.staff_secret_credentials.count
  end
end
