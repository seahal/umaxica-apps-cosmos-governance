# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseOrgRpSignEntryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  BASE_ORG_HOST = HOSTS.base_staff.host
  CLIENT_ID = RpCellBinding.fetch("rp_base_org").client_id
  PENDING_FLOWS_KEY = OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY

  test "GET sign renders a passive Org entry without creating a pending flow" do
    host! BASE_ORG_HOST
    before_count = RpBaseOrgPrincipal.count

    get "/sign", params: { ri: "jp" }

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal before_count, RpBaseOrgPrincipal.count
    form = css_select("form").sole

    assert_equal "post", form["method"]
    assert_equal "/sign", URI.parse(form["action"]).path
    assert_nil session[PENDING_FLOWS_KEY]
  end

  test "POST sign creates an Org-bound PS256 front-channel ID Token flow before handing off through Jump" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    host!(BASE_ORG_HOST)
    https!
    get("/sign", params: { ri: "jp" })

    assert_response :success
    csrf_token = css_select("input[name='authenticity_token']").sole["value"]
    authorization_url = nil
    jump_destination = "https://jump.example.test/redirect?rt=opaque-test-ticket"
    JumpRtIssuer.stub(
      :call, ->(namespace:, url:, dst:, preserve_query_keys:) {
               authorization_url = url
               "opaque-test-ticket"
             },
    ) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_ticket) { RedirectsTargetResult.ok(kind: :external, source: :test, value: jump_destination) },
      ) do
        post(
          "/sign", params: { ri: "jp", authenticity_token: csrf_token }, headers: {
            "Origin" => request.base_url, "Sec-Fetch-Site" => "same-origin",
          },
        )
      end
    end

    assert_response :see_other
    assert_equal jump_destination, response.location
    uri = URI.parse(authorization_url)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    visa_origin = Oidc::AcmeServiceOrigin.from_configured_host(HOSTS.visa_staff.host, default_scheme: "https")

    assert_equal visa_origin.host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal CLIENT_ID, query.fetch("client_id")
    assert_equal "id_token", query.fetch("response_type")
    assert_equal %w(client_id nonce redirect_uri response_type ri scope state), query.keys.sort
    assert_equal "jp", query.fetch("ri")
    assert_equal "/oidc/callback", URI.parse(query.fetch("redirect_uri")).path
    state = OidcStateJwt.verify(client_id: CLIENT_ID, token: query.fetch("state"))

    assert_predicate state, :valid?
    pending = session.fetch(PENDING_FLOWS_KEY).fetch(state.jti)

    assert_equal query.fetch("nonce"), pending.fetch("nonce")
    assert_not pending.key?("code_verifier")
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
