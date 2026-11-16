# frozen_string_literal: true

require "test_helper"

class BaseOrgIdentityOwnerEndpointsTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
  end

  test "selection and standing reject an invalid Governance bearer without disclosing actor data" do
    before = @operator.reload.attributes
    before_selections = RpBaseOrgSessionSelection.count
    [base_org_api_v0_identity_selection_path, base_org_api_v0_identity_standing_path].each do |path|
      assertion = OidcClientAssertionJwt.issue(client_id: "base-org-ww", token_url: "https://#{@host}#{path}")
      get path, headers: { "X-Client-Assertion" => assertion, "Authorization" => "Bearer untrusted-input" }

      assert_response :unauthorized
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_not_includes response.body, @operator.public_id
      assert_equal before, @operator.reload.attributes
      assert_equal before_selections, RpBaseOrgSessionSelection.count
    end
  end

  test "missing malformed replayed and wrong-audience assertion inputs never yield owner data" do
    selection = base_org_api_v0_identity_selection_path
    standing = base_org_api_v0_identity_standing_path
    assertion = OidcClientAssertionJwt.issue(client_id: "base-org-ww", token_url: "https://#{@host}#{selection}")
    [[selection, {}], [selection, { "X-Client-Assertion" => "invalid" }],
     [standing, { "X-Client-Assertion" => assertion }], [selection, { "X-Client-Assertion" => assertion }],
     [selection, { "X-Client-Assertion" => assertion }],].each do |path, headers|
      get path, headers: headers.merge("Authorization" => "Bearer invalid")

      assert_response :unauthorized
      assert_not_includes response.body, @operator.public_id
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end
  end
end
