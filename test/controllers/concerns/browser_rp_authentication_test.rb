# typed: false
# frozen_string_literal: true

require "test_helper"

class BrowserRpAuthenticationProbeController < ApplicationController
  include BrowserRpAuthentication

  def show
    authenticate_browser_rp!
  end
end

class BrowserRpAuthenticationTest < ActionController::TestCase
  tests BrowserRpAuthenticationProbeController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw { get "/probe" => "browser_rp_authentication_probe#show" }
  end

  test "missing Browser RP credentials remain closed without a redirect" do
    get :show

    assert_response :unauthorized
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil response.location
  end

  test "a credential requiring removed OP authority returns explicit unavailable without redirect" do
    @request.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = "external-access-token"

    get :show

    assert_response :service_unavailable
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil response.location
  end
end
