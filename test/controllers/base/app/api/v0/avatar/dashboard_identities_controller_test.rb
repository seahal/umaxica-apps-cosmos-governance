# frozen_string_literal: true

require "test_helper"

class Base::App::Api::V0::Avatar::DashboardIdentitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    https!
    @actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @other_actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @actor)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @other_actor)
    @own = BaseSwitcherAuthority.new(surface: :app, principal: @actor).selectable_candidates.first.fetch(:public)
    @foreign = BaseSwitcherAuthority.new(
      surface: :app,
      principal: @other_actor,
    ).selectable_candidates.first.fetch(:public)
  end

  test "owner cannot resolve own or foreign persona without Access and reveals no dashboard identity" do
    before_actor = @actor.reload.attributes
    before_avatars = Avatar.count
    before_assignments = AvatarAssignment.count
    path = "/api/v0/avatar/app/dashboard-identity"
    [@own, @foreign].each do |selection|
      assertion = OidcClientAssertionJwt.issue(client_id: "base-app-ww", token_url: "https://#{@host}#{path}")
      get path, params: { persona: selection.fetch(:account_public_id),
                          organization_public_id: selection.fetch(:organization_public_id),
                          organization_unit_public_id: selection.fetch(:organization_unit_public_id),
                          avatar_public_id: selection.fetch(:avatar_public_id), },
                headers: { "X-Client-Assertion" => assertion, "Authorization" => "Bearer untrusted-input" }

      assert_response :service_unavailable
      assert_equal "application/problem+json", response.media_type
      assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_not_includes response.body, selection.fetch(:account_public_id)
      assert_not response.parsed_body.key?("display_name")
      assert_equal before_actor, @actor.reload.attributes
      assert_equal before_avatars, Avatar.count
      assert_equal before_assignments, AvatarAssignment.count
    end
  end

  test "missing and malformed credentials never become an owner identity while Access is unavailable" do
    path = "/api/v0/avatar/app/dashboard-identity"
    [{}, { "Authorization" => "Bearer invalid", "X-Client-Assertion" => "invalid" }].each do |headers|
      get path, headers: headers

      assert_response :service_unavailable
      assert_equal "application/problem+json", response.media_type
      assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_not response.parsed_body.key?("display_name")
    end
  end
end
