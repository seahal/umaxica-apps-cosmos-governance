# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::Org::SwitcherControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    @operator = OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
    @token = seed_rp_browser_session(
      client: OidcClientRegistry.find!("base-org-ww"), actor: @operator,
      sid: SecureRandom.uuid, absolute_expires_at: 1.hour.from_now,
    )
  end

  test "unauthenticated operator cannot access switcher" do
    get base_org_switcher_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "authenticated operator can access switcher show" do
    select_token!
    http_headers_3 =
      begin
        as_staff_headers(
          @operator,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    get base_org_selector_url(host: @host), headers: http_headers_3, as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")

    get base_org_switcher_url(host: @host), headers: http_headers_3, as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "HTML switcher page displays the optional Avatar candidate context" do
    select_token!
    http_headers_2 =
      begin
        as_staff_headers(
          @operator,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    get base_org_selector_url(host: @host), headers: http_headers_2, as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")

    get base_org_switcher_url(host: @host, ri: "jp"), headers: http_headers_2

    assert_response :success
    assert_equal "base/org/switchers/show", inertia_component
    assert_equal base_org_dashboard_path(ri: "jp"), inertia_props.dig("up_link", "href")
    assert_nil inertia_props.fetch("candidates").first.fetch("avatar_public_id")
  end

  test "authenticated operator can access switcher update" do
    select_token!
    candidate = BaseSwitcherAuthority.current(
      surface: :org,
      principal: @operator,
      session: @token,
    ).fetch(:candidates).first
    http_headers_1 =
      begin
        as_staff_headers(
          @operator,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    get base_org_selector_url(host: @host), headers: http_headers_1, as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")

    patch base_org_switcher_url(host: @host), headers: http_headers_1, params: {
      account_public_id: candidate.fetch(:public_id),
      organization_public_id: candidate.dig(:organization, :public_id),
      organization_unit_public_id: candidate.dig(:organization, :unit_public_id),
      avatar_public_id: candidate.dig(:avatar, :public_id),
    }, as: :json

    assert_response :success
    assert_equal "switched", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "operator can select an org-owned Avatar without making it the operator identity" do
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    avatar_result = AvatarProvisioning::Create.call(
      actor: @operator,
      subject_type: :agent,
      subject: bootstrap.account,
      avatar_params: { moniker: "Bureau avatar" },
      handle_params: { handle: "bureau-avatar" },
      owner_surface: "org",
      owner_collective_public_id: bootstrap.collective.public_id,
    )

    assert_predicate avatar_result, :success?

    candidates = BaseSwitcherAuthority.current(
      surface: :org,
      principal: @operator,
      session: @token,
    ).fetch(:candidates)
    avatar_candidate =
      candidates.find { |candidate|
        candidate.dig(:avatar, :public_id) == avatar_result.avatar.public_id
      }

    assert avatar_candidate

    http_headers_0 =
      begin
        as_staff_headers(
          @operator,
          host: @host,
          session_public_id: @token.op_session_binding.sid,
        )
      end
    get base_org_selector_url(host: @host), headers: http_headers_0, as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")

    patch base_org_switcher_url(host: @host), headers: http_headers_0, params: {
      account_public_id: avatar_candidate.fetch(:public_id),
      organization_public_id: avatar_candidate.dig(:organization, :public_id),
      organization_unit_public_id: avatar_candidate.dig(:organization, :unit_public_id),
      avatar_public_id: avatar_candidate.dig(:avatar, :public_id),
    }, as: :json

    assert_response :success
    assert_equal "switched", response.parsed_body.fetch("status")
    rp_session_key = ["base-org-ww", @operator.public_id, @token.op_session_binding.sid]
    rp_session = RpBaseOrgSession.find_by!(public_id: @base_browser_rp_session_public_ids.fetch(rp_session_key))
    rp_selection = RpBaseOrgSessionSelection.find_by!(rp_session_id: rp_session.id)
    avatar_selection = RpBaseOrgSessionAvatarSelection.find_by!(rp_session_id: rp_session.id)

    assert_equal avatar_result.avatar.public_id, avatar_selection.avatar_public_id
    assert_equal bootstrap.account.public_id, rp_selection.account_public_id
    assert_equal bootstrap.account.public_id, rp_selection.account_public_id
  end

  private

  def select_token!
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.select(
      surface: :org, principal: @operator, session: @token,
      params: {
        account_public_id: bootstrap.account.public_id,
        organization_public_id: bootstrap.collective.public_id,
        organization_unit_public_id: bootstrap.unit.public_id,
        avatar_public_id: bootstrap.avatar&.public_id,
      },
    )
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::Org::SwitcherControllerTest
  private
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::Org::SwitcherControllerTest
  private

  def set_access_cookie(token)
    cookies[AuthenticationCookieName.access] = token
  end

  # Derive the issuer id from the test host. Base RP hosts (www.umaxica.app/.org)
  # must resolve to surface:BASE_* so the access token issuer matches the surface the
  # controller validates against.
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      elsif normalized.include?("auth") || normalized.include?("sign") || normalized.include?("log.umaxica")
        "AUTH"
      else
        "BASE"
      end
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end
