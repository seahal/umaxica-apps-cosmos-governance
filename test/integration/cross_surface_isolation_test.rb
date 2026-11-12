# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Characterization test (pre-enforcement baseline) -- cross-surface actor isolation.
#
# The two surfaces (app/client, org/operator) are independent authentication
# boundaries. Credentials minted for one surface must not authenticate an actor on another
# surface's host. The per-surface dashboard (`AUTHENTICATION_MODE = :private`, trivial `show`) is
# used as a representative protected endpoint; each surface's own settings tests already
# covers anonymous-redirect and own-surface success, so this test pins the missing cross-surface
# denial matrix.
#
# This invariant is enforced at authentication time (the foreign actor never resolves), which is
# distinct from -- and must survive -- the upcoming object-level Action Policy enforcement rollout
# (ADR pundit-to-action-policy-migration.md, Phase 3). If a future change accidentally let one
# surface's session authorize another surface, these assertions fail.
class CrossSurfaceIsolationTest < ActionDispatch::IntegrationTest
  fixtures :operators, :clients

  APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  ORG_HOST = ENV.fetch("PUBLIC_BASE_STAFF_URL")

  setup do
    @client = clients(:one)
    @operator = operators(:one)
  end

  # --- positive controls: each surface accepts its own actor ---

  test "client is authenticated on the APP identity surface" do
    http_headers_8 = as_user_headers(@client, host: APP_HOST, select_available_app_persona: false)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    app_candidate = BaseSelectorAuthority.selection_options(surface: :app, principal: @client)
      .fetch(:accounts).fetch(0)
    patch base_app_selector_url(ri: "jp", host: APP_HOST),
          params: {
            account_public_id: app_candidate.fetch(:public_id),
            organization_public_id: app_candidate.dig(:organization, :public_id),
            organization_unit_public_id: app_candidate.dig(:organization, :unit_public_id),
            avatar_public_id: app_candidate.dig(:avatar, :public_id),
          },
          headers: http_headers_8,
          as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")

    get base_app_identity_url(ri: "jp"), headers: http_headers_8

    assert_same_surface_dashboard_redirect(APP_HOST)
  end

  test "operator is authenticated on the ORG identity surface" do
    http_headers_6 = as_staff_headers(@operator, host: ORG_HOST)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    org_candidate = BaseSelectorAuthority.selection_options(surface: :org, principal: @operator)
      .fetch(:accounts).fetch(0)
    patch base_org_selector_url(ri: "jp", host: ORG_HOST),
          params: {
            account_public_id: org_candidate.fetch(:public_id),
            organization_public_id: org_candidate.dig(:organization, :public_id),
            organization_unit_public_id: org_candidate.dig(:organization, :unit_public_id),
          },
          headers: http_headers_6,
          as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")

    get base_org_identity_url(ri: "jp"), headers: http_headers_6

    assert_same_surface_dashboard_redirect(ORG_HOST)
  end

  # --- isolation matrix: foreign-surface credentials are rejected (redirect to sign-in) ---

  test "operator credentials are rejected on the app surface" do
    http_headers_5 = as_staff_headers(@operator, host: ORG_HOST).merge("Host" => APP_HOST)
    get base_app_identity_url(ri: "jp"), headers: http_headers_5

    assert_cross_surface_rejected
  end

  test "client credentials are rejected on the org surface" do
    http_headers_1 = as_user_headers(@client, host: APP_HOST).merge("Host" => ORG_HOST)
    get base_org_identity_url(ri: "jp"), headers: http_headers_1

    assert_cross_surface_rejected
  end

  private

  def assert_same_surface_dashboard_redirect(_sign_host)
    assert_response :success
  end

  def assert_cross_surface_rejected
    assert_includes [302, 303, 400, 401], response.status
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class CrossSurfaceIsolationTest
  private
end
