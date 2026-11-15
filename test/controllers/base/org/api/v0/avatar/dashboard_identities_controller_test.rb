# frozen_string_literal: true

require "test_helper"

class Base::Org::Api::V0::Avatar::DashboardIdentitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
    @actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @other_actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @actor)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @other_actor)
    rp_cell = RpCellBinding.fetch("rp_base_org")
    visa_issuer = Oidc::AcmeServiceOrigin.from_configured_host(
      Rails.configuration.x.boot_config.fetch(:hosts).visa_staff.host, default_scheme: "https",
    ).origin
    id_token_jti_digest = Digest::SHA256.hexdigest("base-org-api-test-id-token")
    callback = RpCallbackCommitter.call(
      cell: rp_cell,
      issuer: visa_issuer,
      subject: OidcSubject.for(@actor, resource_type: "operator"),
      sid: "base-org-api-test-sid",
      absolute_expires_at: 1.hour.from_now,
      id_token_jti_digest:,
      id_token_expires_at: 2.minutes.from_now,
      authentication_evidence: {
        "acr" => "urn:umaxica:base:normal",
        "amr" => ["pwd"],
        "auth_time" => Time.current.to_i,
        "id_token_jti_digest" => id_token_jti_digest,
      },
    )

    assert_predicate callback, :success?
    @rp_session = callback.session
    @own = BaseSwitcherAuthority.new(surface: :org, principal: @actor).selectable_candidates.first.fetch(:public)
    @foreign = BaseSwitcherAuthority.new(
      surface: :org,
      principal: @other_actor,
    ).selectable_candidates.first.fetch(:public)
  end

  test "a Governance bearer resolves its active RP session and still refuses a foreign persona" do
    before_actor = @actor.reload.attributes
    before_avatars = Avatar.count
    before_assignments = AvatarAssignment.count
    path = "/api/v0/avatar/org/dashboard-identity"
    token = BaseApiAuthorityTokenIssuer.issue(rp_session: @rp_session)
    [[@own, :ok], [@foreign, :forbidden]].each do |selection, expected_response|
      get path, params: { persona: selection.fetch(:account_public_id),
                          organization_public_id: selection.fetch(:organization_public_id),
                          organization_unit_public_id: selection.fetch(:organization_unit_public_id),
                          avatar_public_id: selection.fetch(:avatar_public_id), },
                headers: { "Authorization" => "Bearer #{token}" }

      assert_response expected_response
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_equal before_actor, @actor.reload.attributes
      assert_equal before_avatars, Avatar.count
      assert_equal before_assignments, AvatarAssignment.count
    end
  end

  test "missing or malformed Governance bearers never become an owner identity" do
    path = "/api/v0/avatar/org/dashboard-identity"
    [{}, { "Authorization" => "Bearer invalid" }, { "Authorization" => "Basic credentials" }].each do |headers|
      get path, headers: headers

      assert_response :unauthorized
      assert_equal({ "error" => "invalid_token" }, response.parsed_body)
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_not response.parsed_body.key?("display_name")
    end
  end
end
