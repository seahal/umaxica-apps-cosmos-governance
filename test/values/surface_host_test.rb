# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SurfaceHostTest < ActiveSupport::TestCase
  class MockRequest
    attr_accessor :host

    def initialize(host)
      @host = host
    end
  end

  test "detect returns app for app subdomain" do
    request = MockRequest.new("app.example.com")

    assert_equal :app, SurfaceHost.detect(request)
  end

  test "detect returns com for com subdomain" do
    request = MockRequest.new("example.com")

    assert_equal :com, SurfaceHost.detect(request)
  end

  test "detect returns org for org subdomain" do
    request = MockRequest.new("org.example.com")

    assert_equal :org, SurfaceHost.detect(request)
  end

  test "detect returns unknown for an unrecognized host" do
    request = MockRequest.new("unknown.example.test")

    assert_equal :unknown, SurfaceHost.detect(request)
  end

  test "detect returns unknown for blank host" do
    request = MockRequest.new("")

    assert_equal :unknown, SurfaceHost.detect(request)
  end

  test "detect returns unknown for nil host" do
    request = MockRequest.new(nil)

    assert_equal :unknown, SurfaceHost.detect(request)
  end

  test "detect returns app for deeply nested app subdomain" do
    request = MockRequest.new("deep.app.nested.example.com")

    assert_equal :app, SurfaceHost.detect(request)
  end

  test "detect is case insensitive" do
    request = MockRequest.new("APP.EXAMPLE.COM")

    assert_equal :app, SurfaceHost.detect(request)
  end

  test "detect handles host with port" do
    request = MockRequest.new("app.example.com:3000")

    assert_equal :app, SurfaceHost.detect(request)
  end

  test "current delegates to detect" do
    request = MockRequest.new("app.example.com")

    assert_equal :app, SurfaceHost.current(request)
  end

  test "matches returns true when surface matches" do
    request = MockRequest.new("app.example.com")

    assert SurfaceHost.matches?(request, :app)
  end

  test "matches returns false when surface does not match" do
    request = MockRequest.new("app.example.com")

    assert_not SurfaceHost.matches?(request, :org)
  end
end
