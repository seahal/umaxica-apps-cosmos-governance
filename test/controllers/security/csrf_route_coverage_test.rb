# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
# require "helpers/csrf_route_coverage_helper"

module Security
  class CsrfRouteCoverageTest < ActiveSupport::TestCase
    # include CsrfRouteCoverageHelper

    self.fixture_table_names = []

    NULL_SESSION_STRATEGY = ActionController::RequestForgeryProtection::ProtectionMethods::NullSession
    PROTOCOL_ENDPOINTS = [
      # Retained Base owner APIs use server-to-server authentication without browser cookies.
      %r{\A/api/v0/(?:avatar|membership|iam|support|tech-capability-checks)/},
      %r{\A/api/v0/tech-capability-checks(?:\(\.:format\))?\z},
    ].freeze

    test "retired OP and publishing paths are not exempt from the CSRF route invariant" do
      %w(/oauth/token /oauth/revoke /apple/notifications /oidc/closures /api/v0/publishing/entries).each do |path|
        assert_not PROTOCOL_ENDPOINTS.any? { |pattern| pattern.match?(path) }, path
      end
    end

    test "only API controllers use the server-to-server CSRF invariant exception" do
      exceptions = state_changing_application_route_targets.select { |target| protocol_endpoint?(target) }

      assert_not_empty exceptions
      browser_controllers = exceptions.reject { |target| target.fetch(:controller_class) < ActionController::API }

      assert_empty browser_controllers.map { |target| "#{target.fetch(:path)} -> #{target.fetch(:controller)}" }
    end

    test "state-changing application routes do not use null-session csrf handling" do
      violations =
        state_changing_application_route_targets.filter_map do |target|
          next if protocol_endpoint?(target)
          next unless target.fetch(:controller_class).forgery_protection_strategy == NULL_SESSION_STRATEGY

          "#{target.fetch(:verb)} #{target.fetch(:path)} -> " \
            "#{target.fetch(:controller)}##{target.fetch(:action)}"
        end

      assert_empty violations,
                   "State-changing routes must reject missing/invalid CSRF tokens instead of " \
                   "using null_session. Review:\n  #{violations.join("\n  ")}"
    end

    private

    def protocol_endpoint?(target)
      PROTOCOL_ENDPOINTS.any? { |pattern| pattern.match?(target.fetch(:path)) }
    end
  end
  private

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route_verbs(route)
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class = controller_class_for(controller)
      next unless controller_class

      {
        verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: controller_class,
      }
    end
  end

  def route_verbs(route)
    route.verb.to_s.delete("^A-Z|").split("|")
  end

  def controller_class_for(controller)
    controller_class_name = "#{controller.camelize}Controller"
    return nil unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

    Object.const_get(controller_class_name)
  rescue NameError
    nil
  end
end

# DAMP local helper copy on the test class.
class Security::CsrfRouteCoverageTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
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
