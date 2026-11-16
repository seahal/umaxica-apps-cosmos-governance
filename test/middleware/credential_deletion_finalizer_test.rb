# typed: false
# frozen_string_literal: true

require "test_helper"

class CredentialDeletionFinalizerProbeController < ApplicationController
  include BrowserRpAuthentication

  AUTHENTICATION_MODE = :open

  declare_authentication_mode! :open
  before_action :enforce_access_policy!

  public

  def show
    raise ActiveRecord::RecordNotFound, "test boundary after credential refusal"
  end

  protected

  def browser_rp_access_state
    BrowserRpAuthentication::AccessState.new(
      status: :invalid, resource: nil, rp_session: nil, payload: nil, security_context: nil,
    )
  end
end

class CredentialDeletionFinalizerTest < ActiveSupport::TestCase
  test "a confirmed RP access deletion survives the exception response" do
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw { get "/probe" => "credential_deletion_finalizer_probe#show" }
    exceptions = ActionDispatch::PublicExceptions.new(Rails.public_path)
    app = CredentialDeletionFinalizer.new(ActionDispatch::ShowExceptions.new(routes, exceptions))
    env = Rack::MockRequest.env_for(
      "https://base.app.localhost/probe",
      "HTTP_COOKIE" => "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=unusable",
    )
    env["rack.session"] = {}
    env["action_dispatch.show_exceptions"] = :rescuable

    status, headers, = app.call(env)

    assert_equal 404, status
    deletion =
      Array(headers[Rack::SET_COOKIE]).find do |line|
        line.start_with?("#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=")
      end

    assert_predicate deletion, :present?
    assert_match(/(?:max-age=0|expires=Thu, 01 Jan 1970)/i, deletion)
    assert_no_match(/#{Regexp.escape(OidcRpBrowserCredentialContract::REFRESH_COOKIE)}=/, deletion)
    assert_no_match(/#{Regexp.escape(OidcRpBrowserCredentialContract::SESSION_COOKIE)}=/, deletion)
  end

  test "a deletion registration is not duplicated over a later cookie write" do
    cookie_name = OidcRpBrowserCredentialContract::ACCESS_COOKIE
    options = OidcRpBrowserCredentialContract.access_cookie_deletion_options
    app =
      lambda do |env|
        CredentialDeletionFinalizer.register(env, cookie_name, options)
        [200, { Rack::SET_COOKIE => ["#{cookie_name}=replacement; Path=/"] }, ["ok"]]
      end

    status, headers, body = CredentialDeletionFinalizer.new(app).call({})

    assert_equal 200, status
    assert_equal ["#{cookie_name}=replacement; Path=/"], headers.fetch(Rack::SET_COOKIE)
    assert_equal ["ok"], body
  end

  test "a blank registered cookie name raises" do
    assert_raises(ArgumentError) do
      CredentialDeletionFinalizer.register({}, " ", {})
    end
  end
end
