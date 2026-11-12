# typed: false
# frozen_string_literal: true

require "test_helper"

# Contract for the Rails-side Inertia protocol on the only Inertia endpoint in the application
# (Base::App::IdentitiesController#show).
#
# The pre-existing controller test asserted HTML substrings only, so it could not observe the page
# object Inertia actually navigates on: component, props, url, version. Every assertion here reads
# the protocol payload rather than the markup around it.
class InertiaPageContractTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
  end

  test "initial response embeds the full page object, not just a component name" do
    http_headers_12 = as_user_headers(@user, host: @host)
    get(
      base_app_identity_url(ri: "jp", host: @host), headers: http_headers_12,
    )

    assert_response :success

    page = initial_page

    assert_equal "base/app/identities/show", page.fetch("component")
    assert_equal "Identity", page.dig("props", "title")
    assert_kind_of Array, page.dig("props", "sections")
    assert_equal ViteRuby.digest, page.fetch("version")
    assert page.fetch("encryptHistory"), "encrypt_history is configured on, so the page must carry it"
  end

  # The `url` key is the client's notion of the current page. Inertia resolves every subsequent
  # visit and every history entry against it, so a wrong value desynchronises the SPA from the
  # address bar.
  test "initial page url is the requested path including the query string" do
    http_headers_11 = as_user_headers(@user, host: @host)
    get(
      base_app_identity_url(ri: "jp", host: @host), headers: http_headers_11,
    )

    assert_response :success
    assert_equal "/identity?ri=jp", initial_page.fetch("url")
  end

  test "an Inertia visit returns the page object as JSON with the same current page url" do
    http_headers_10 =
      begin
        fx0_version = ViteRuby.digest
        begin
          f0_headers = as_user_headers(@user, host: @host)
          f0_headers
        end.merge(inertia_headers(version: fx0_version))
      end
    get(
      base_app_identity_url(ri: "jp", host: @host),
      headers: http_headers_10,
    )

    assert_response :success
    assert_equal "true", response.headers["X-Inertia"]
    assert_equal "application/json", response.media_type

    page = response.parsed_body

    assert_equal "base/app/identities/show", page.fetch("component")
    assert_equal "/identity?ri=jp", page.fetch("url")
    assert_equal ViteRuby.digest, page.fetch("version")
  end

  # Inertia.js 3 reads the initial page from a JSON <script> element keyed by the root element id.
  # The older form, a `data-page` attribute on the root element, is not read by the client at all.
  # The root element id is the inertia_rails default, and `createInertiaApp` is booted without an
  # `id` override (gait/entrypoints/inertia.test.ts), so both sides meet on the upstream default.
  test "initial response carries the page in a script element and leaves the root element bare" do
    http_headers_9 = as_user_headers(@user, host: @host)
    get(
      base_app_identity_url(ri: "jp", host: @host), headers: http_headers_9,
    )

    assert_response :success
    assert_select "script[data-page='app'][type='application/json']", count: 1
    assert_select "div#app", count: 1
    assert_select "div[data-page]", count: 0
  end

  test "initial page script carries the response CSP nonce" do
    http_headers_8 = as_user_headers(@user, host: @host)
    get(
      base_app_identity_url(ri: "jp", host: @host), headers: http_headers_8,
    )

    assert_response :success

    nonce = css_select("meta[property='csp-nonce']").first["nonce"]

    assert_predicate nonce, :present?
    assert_equal nonce, css_select("script[data-page='app']").first["nonce"]
  end

  test "a page with no validation failure still carries an empty errors hash" do
    http_headers_7 = as_user_headers(@user, host: @host)
    get(
      base_app_identity_url(ri: "jp", host: @host), headers: http_headers_7,
    )

    assert_response :success
    assert_empty(initial_page.fetch("props").fetch("errors"))

    http_headers_6 =
      begin
        fx1_version = ViteRuby.digest
        begin
          f1_headers = as_user_headers(@user, host: @host)
          f1_headers
        end.merge(inertia_headers(version: fx1_version))
      end
    get(
      base_app_identity_url(ri: "jp", host: @host),
      headers: http_headers_6,
    )

    assert_response :success
    assert_empty(response.parsed_body.fetch("props").fetch("errors"))
  end

  test "history is encrypted and not cleared on an ordinary page, initial and Inertia alike" do
    http_headers_5 = as_user_headers(@user, host: @host)
    get(
      base_app_identity_url(ri: "jp", host: @host), headers: http_headers_5,
    )

    assert_response :success
    assert initial_page.fetch("encryptHistory")
    # inertia_rails omits clearHistory from the page object when it is false.
    assert_not initial_page.fetch("clearHistory", false)

    http_headers_4 =
      begin
        fx2_version = ViteRuby.digest
        begin
          f2_headers = as_user_headers(@user, host: @host)
          f2_headers
        end.merge(inertia_headers(version: fx2_version))
      end
    get(
      base_app_identity_url(ri: "jp", host: @host),
      headers: http_headers_4,
    )

    assert_response :success
    assert response.parsed_body.fetch("encryptHistory")
    assert_not response.parsed_body.fetch("clearHistory", false)
  end

  # The page url is origin-relative by protocol: it never names a host, so one tenant's host cannot
  # reach another tenant's page object through it. Partitions: several parameters, and a
  # percent-encoded non-ASCII value, which must come back byte for byte rather than re-encoded.
  test "page url keeps several query parameters and stays origin-relative" do
    http_headers_3 =
      begin
        fx3_version = ViteRuby.digest
        begin
          f3_headers = as_user_headers(@user, host: @host)
          f3_headers
        end.merge(inertia_headers(version: fx3_version))
      end
    get(
      base_app_identity_url(ri: "jp", page: "2", host: @host),
      headers: http_headers_3,
    )

    assert_response :success
    assert_equal "/identity?page=2&ri=jp", response.parsed_body.fetch("url")
  end

  test "page url keeps a percent-encoded non-ASCII query value unchanged" do
    http_headers_2 =
      begin
        fx4_version = ViteRuby.digest
        begin
          f4_headers = as_user_headers(@user, host: @host)
          f4_headers
        end.merge(inertia_headers(version: fx4_version))
      end
    get(
      "https://#{@host}/identity?ri=jp&q=%E6%9D%B1%E4%BA%AC%20a%2Bb",
      headers: http_headers_2,
    )

    assert_response :success
    assert_equal "/identity?ri=jp&q=%E6%9D%B1%E4%BA%AC%20a%2Bb", response.parsed_body.fetch("url")
  end

  # The version is derived from the Vite sources once per process, so a request for another
  # tenant's host cannot make it differ.
  test "asset version is identical for an Inertia page served on another surface host" do
    http_headers_1 =
      begin
        fx5_version = ViteRuby.digest
        begin
          f5_headers = as_user_headers(@user, host: @host)
          f5_headers
        end.merge(inertia_headers(version: fx5_version))
      end
    get(
      base_app_identity_url(ri: "jp", host: @host),
      headers: http_headers_1,
    )

    assert_response :success

    app_version = response.parsed_body.fetch("version")
    com_host = configured_host(:base_corporate)

    get(
      base_com_preference_url(ri: "jp", host: com_host),
      headers: { "Host" => com_host, "X-Inertia" => "true", "X-Inertia-Version" => app_version },
    )

    assert_response :success
    assert_equal app_version, response.parsed_body.fetch("version")
  end

  # The stale-version refresh names the request's own origin. Sent to the com host, it must come
  # back for the com host and never for the app host this test class otherwise uses.
  test "a stale version refresh on another surface host names that host and keeps the query" do
    com_host = configured_host(:base_corporate)

    get(
      base_com_preference_url(ri: "jp", host: com_host),
      headers: { "Host" => com_host, "X-Inertia" => "true", "X-Inertia-Version" => "stale-asset-version" },
    )

    assert_response :conflict

    location = URI.parse(response.headers["X-Inertia-Location"])

    assert_equal com_host, location.host
    assert_equal "/preference", location.path
    assert_equal "ri=jp", location.query
    assert_not_equal @host, location.host
  end

  test "an Inertia visit carrying a stale asset version is answered with a hard location refresh" do
    http_headers_0 =
      begin
        fx6_version = "stale-asset-version"
        begin
          f6_headers = as_user_headers(@user, host: @host)
          f6_headers
        end.merge(inertia_headers(version: fx6_version))
      end
    get(
      base_app_identity_url(ri: "jp", host: @host),
      headers: http_headers_0,
    )

    assert_response :conflict
    assert_equal(
      base_app_identity_url(ri: "jp", host: @host),
      response.headers["X-Inertia-Location"],
    )
  end

  test "an unauthenticated Inertia visit is unauthorized without a sign-in route" do
    get(base_app_identity_url(ri: "jp", host: @host), headers: inertia_headers(version: ViteRuby.digest))

    assert_response :unauthorized
    assert_nil response.headers["X-Inertia-Location"]
  end

  test "a plain unauthenticated browser request is unauthorized" do
    get(base_app_identity_url(ri: "jp", host: @host), headers: host_headers(@host))

    assert_response :unauthorized
  end

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def inertia_headers(version: nil)
    headers = host_headers(@host).merge(
      "X-Inertia" => "true",
      "Accept" => "text/html, application/xhtml+xml",
    )
    headers["X-Inertia-Version"] = version if version
    headers
  end

  def initial_page
    element = css_select("script[data-page='app']").first

    assert element, "the initial response must embed the Inertia page object"

    JSON.parse(element.text)
  end
end
