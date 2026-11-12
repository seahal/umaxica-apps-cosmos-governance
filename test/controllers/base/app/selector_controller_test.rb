# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
# require "helpers/auth_helpers"

class Base::App::SelectorControllerTest < ActionDispatch::IntegrationTest
  # include AuthHelpers

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @external_session_ref = SecureRandom.uuid
  end

  test "unauthenticated identity cannot access selector" do
    get base_app_selector_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "unauthenticated html selector refuses without an Access sign-in entry" do
    get base_app_selector_url(host: @host, ri: "jp"), headers: host_headers(@host)

    assert_response :unauthorized
    assert_nil response.location
  end

  test "authenticated RP session automatically selects its only candidate" do
    http_headers_6 = as_user_headers(
      @user, host: @host, session_public_id: @external_session_ref,
             select_available_app_persona: false,
    )
    candidate = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    get base_app_selector_url(host: @host), headers: http_headers_6, as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal "selected", body.fetch("status")
    assert_equal @external_session_ref, RpBaseAppSession.includes(:op_session_binding).find_by!(
      public_id: @base_browser_rp_session_public_ids.fetch(
        [RpBaseAppSession::CLIENT_ID, @user.public_id, @external_session_ref],
      ),
    ).op_session_binding.sid
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @external_session_ref,],
    )
    rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: rp_session_id)
    selection = RpBaseAppSessionSelection.find_by!(rp_session_id: rp_session.id)

    assert_equal 1, BaseSelectorAuthority.new(surface: :app, principal: @user, session: rp_session)
      .selectable_candidates.length
    assert_equal candidate.account.public_id, selection.account_public_id
  end

  test "freshly provisioned identity is automatically selected when it has one candidate" do
    IdentityGraphProvisioner.call!(surface: :app, principal: @user)

    http_headers_5 = as_user_headers(
      @user, host: @host, session_public_id: @external_session_ref,
             select_available_app_persona: false,
    )
    get base_app_selector_url(host: @host), headers: http_headers_5, as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    assert_equal @external_session_ref, RpBaseAppSession.includes(:op_session_binding).find_by!(
      public_id: @base_browser_rp_session_public_ids.fetch(
        [RpBaseAppSession::CLIENT_ID, @user.public_id, @external_session_ref],
      ),
    ).op_session_binding.sid
    assert_equal 1, ClientIdentity.where(source_record_id: @user.id).count
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @external_session_ref,],
    )
    rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: rp_session_id)

    assert_predicate RpBaseAppSessionSelection.find_by!(rp_session_id: rp_session.id), :persisted?
    assert_equal 1, BaseSelectorAuthority.new(surface: :app, principal: @user, session: rp_session)
      .selectable_candidates.length
  end

  test "html selector automatically selects the only RP-local candidate" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    http_headers_4 =
      begin
        as_user_headers(
          @user, host: @host, session_public_id: @external_session_ref, select_available_app_persona: false,
        )
      end
    get base_app_selector_url(host: @host, ri: "jp"),
        headers: http_headers_4

    assert_response :redirect
    assert_redirected_to base_app_dashboard_path(ri: "jp")
    assert_equal @external_session_ref, RpBaseAppSession.includes(:op_session_binding).find_by!(
      public_id: @base_browser_rp_session_public_ids.fetch(
        [RpBaseAppSession::CLIENT_ID, @user.public_id, @external_session_ref],
      ),
    ).op_session_binding.sid
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @external_session_ref,],
    )
    rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: rp_session_id)
    candidates = BaseSelectorAuthority.new(surface: :app, principal: @user, session: rp_session)
      .selectable_candidates

    selection = RpBaseAppSessionSelection.find_by!(rp_session_id: rp_session.id)

    assert_equal 1, candidates.size
    assert_equal candidates.first.dig(:public, :account_public_id), selection.account_public_id
  end

  test "html selector request for an already selected session redirects to switcher" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    http_headers_3 = as_user_headers(@user, host: @host, session_public_id: @external_session_ref)
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @external_session_ref,],
    )
    rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: rp_session_id)
    candidate = BaseSelectorAuthority.new(
      surface: :app, principal: @user, session: rp_session,
    ).selectable_candidates.first
    patch base_app_selector_url(host: @host, ri: "jp"),
          params: candidate.fetch(:public),
          headers: http_headers_3,
          as: :json

    assert_response :conflict
    assert_equal "already_selected", response.parsed_body.fetch("status")
    assert_equal base_app_switcher_path(ri: "jp"), response.parsed_body.fetch("next")

    get base_app_selector_url(host: @host, ri: "jp"),
        headers: http_headers_3

    assert_redirected_to base_app_switcher_path(ri: "jp")
    assert_not_equal base_app_root_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal @external_session_ref, RpBaseAppSession.includes(:op_session_binding).find_by!(
      public_id: @base_browser_rp_session_public_ids.fetch(
        [RpBaseAppSession::CLIENT_ID, @user.public_id, @external_session_ref],
      ),
    ).op_session_binding.sid
  end

  test "RP selector ignores an untrusted OP flow reference after the RP session is established" do
    binding = "unowned-op-flow-reference"

    auth_headers =
      begin
        as_user_headers(
          @user, host: @host, session_public_id: @external_session_ref, select_available_app_persona: false,
        )
      end
    get base_app_selector_url(host: @host, ri: "jp", fb: binding), headers: auth_headers, as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    assert_equal @external_session_ref, RpBaseAppSession.includes(:op_session_binding).find_by!(
      public_id: @base_browser_rp_session_public_ids.fetch(
        [RpBaseAppSession::CLIENT_ID, @user.public_id, @external_session_ref],
      ),
    ).op_session_binding.sid
    session_public_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @external_session_ref,],
    )
    session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: session_public_id)

    assert_predicate RpBaseAppSessionSelection.find_by!(rp_session_id: session.id), :persisted?
  end

  test "json selector request stays json when the RP session has a local selection" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    http_headers_2 = as_user_headers(@user, host: @host, session_public_id: @external_session_ref)
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @external_session_ref,],
    )
    rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: rp_session_id)
    candidate = BaseSelectorAuthority.new(
      surface: :app, principal: @user, session: rp_session,
    ).selectable_candidates.first
    patch base_app_selector_url(host: @host, ri: "jp"),
          params: candidate.fetch(:public),
          headers: http_headers_2,
          as: :json

    assert_response :conflict
    assert_equal "already_selected", response.parsed_body.fetch("status")
    assert_equal base_app_switcher_path(ri: "jp"), response.parsed_body.fetch("next")

    get base_app_selector_url(host: @host, ri: "jp"),
        headers: http_headers_2,
        as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    assert_nil response.location
    assert_equal @external_session_ref, RpBaseAppSession.includes(:op_session_binding).find_by!(
      public_id: @base_browser_rp_session_public_ids.fetch(
        [RpBaseAppSession::CLIENT_ID, @user.public_id, @external_session_ref],
      ),
    ).op_session_binding.sid
  end

  test "selector update persists valid selected actor context" do
    http_headers_1 =
      begin
        as_user_headers(
          @user, host: @host, session_public_id: @external_session_ref, select_available_app_persona: false,
        )
      end
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @external_session_ref,],
    )
    rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: rp_session_id)
    candidate = BaseSelectorAuthority.new(
      surface: :app, principal: @user, session: rp_session,
    ).selectable_candidates.first
    patch base_app_selector_url(host: @host),
          params: candidate[:public],
          headers: http_headers_1,
          as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    rp_session_id = @base_browser_rp_session_public_ids.fetch(
      [RpBaseAppSession::CLIENT_ID, @user.public_id,
       @external_session_ref,],
    )
    rp_session = RpBaseAppSession.includes(:op_session_binding).find_by!(public_id: rp_session_id)
    selection = RpBaseAppSessionSelection.find_by!(rp_session_id: rp_session.id)

    assert_equal candidate.fetch(:public).fetch(:account_public_id), selection.account_public_id
    assert_equal @external_session_ref, RpBaseAppSession.includes(:op_session_binding).find_by!(
      public_id: @base_browser_rp_session_public_ids.fetch(
        [RpBaseAppSession::CLIENT_ID, @user.public_id, @external_session_ref],
      ),
    ).op_session_binding.sid
  end

  test "selector update renders invalid selection error as json" do
    BaseSelectorAuthority.stub(:select, ->(*) { raise BaseSelectorAuthority::InvalidSelection, "bad" }) do
      http_headers_0 =
        begin
          as_user_headers(
            @user, host: @host, session_public_id: @external_session_ref, select_available_app_persona: false,
          )
        end
      patch base_app_selector_url(host: @host),
            params: { account_public_id: "invalid" },
            headers: http_headers_0,
            as: :json
    end

    assert_response :unprocessable_content
    assert_equal "invalid_selection", response.parsed_body.fetch("status")
    assert_equal @external_session_ref, RpBaseAppSession.includes(:op_session_binding).find_by!(
      public_id: @base_browser_rp_session_public_ids.fetch(
        [RpBaseAppSession::CLIENT_ID, @user.public_id, @external_session_ref],
      ),
    ).op_session_binding.sid
  end

  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::App::SelectorControllerTest
  private
end

# DAMP local helper copy for former shared test support.
class Base::App::SelectorControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("core")
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

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local helper copy on the test class.
class Base::App::SelectorControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

  def set_access_cookie(token)
    cookies[AuthenticationCookieName.access] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationCookieName.refresh] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(FOREIGN_APP FOREIGN_ORG BASE_APP BASE_ORG).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end
end
