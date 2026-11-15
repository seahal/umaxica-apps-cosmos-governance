# frozen_string_literal: true

require "test_helper"

class Base::Org::DashboardAvatarImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @principal = principal = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
    )
    2.times do |index|
      OperatorPasskey.create!(
        staff: principal, webauthn_id: "image-fixture-#{index}", external_id: SecureRandom.uuid,
        public_key: "image-fixture-key-#{index}", description: "Image fixture",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: principal)
    @headers = as_staff_headers(principal, host: @host)
    session_id = Rack::Utils.parse_cookies_header(@headers.fetch("Cookie")).fetch(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
    )
    @rp_session = RpBaseOrgSession.includes(:op_session_binding).find_by!(public_id: session_id)
    BaseSelectorAuthority.select(
      surface: :org, principal: principal, session: @rp_session,
      params: {
        account_public_id: bootstrap.account.public_id,
        organization_public_id: bootstrap.collective.public_id,
        organization_unit_public_id: bootstrap.unit.public_id,
      },
    )
  end

  test "the public selector refuses a binding revoked after the fixture session was loaded" do
    selection = RpBaseOrgSessionSelection.find_by!(rp_session_id: @rp_session.id)
    original = selection.attributes
    @rp_session.op_session_binding.revoke!

    assert_raises(BaseSelectorAuthority::InvalidSelection) do
      BaseSelectorAuthority.select(
        surface: :org, principal: @principal, session: @rp_session,
        params: {
          account_public_id: selection.account_public_id,
          organization_public_id: selection.organization_public_id,
          organization_unit_public_id: selection.organization_unit_public_id,
        },
      )
    end
    assert_equal original, selection.reload.attributes
  end

  test "anonymous image reads cannot initiate an owner or sign-in workflow" do
    get base_org_dashboard_avatar_image_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :unauthorized
    assert_empty response.body
    assert_nil response.location
  end

  test "verified RP image GET and HEAD return not found without a cacheable response or session write" do
    original_session = @rp_session.reload.attributes
    selection = RpBaseOrgSessionSelection.find_by!(rp_session_id: @rp_session.id)
    original_selection = selection.attributes
    image_headers = @headers.merge("Accept" => "image/png", "If-None-Match" => '"previous-owner-image"')

    get base_org_dashboard_avatar_image_url(ri: "jp", host: @host), headers: image_headers

    assert_response :not_found
    assert_empty response.body
    assert_nil response.headers["ETag"]
    assert_nil response.location
    head base_org_dashboard_avatar_image_url(ri: "jp", host: @host), headers: image_headers

    assert_response :not_found
    assert_empty response.body
    assert_nil response.headers["ETag"]
    assert_equal original_session, @rp_session.reload.attributes
    assert_equal original_selection, selection.reload.attributes
  end
end
