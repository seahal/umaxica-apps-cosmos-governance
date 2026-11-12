# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class HostContextResolverTest < ActiveSupport::TestCase
  Request = Struct.new(:host)

  test "resolves app surface from host" do
    context = HostContextResolver.call(Request.new("www.app.localhost"))

    assert_equal :app, context.surface
    assert_nil context.account
    assert_nil context.tenant
  end

  test "resolves org surface from host" do
    context = HostContextResolver.call(Request.new("id.org.localhost"))

    assert_equal :org, context.surface
  end

  test "keeps an unrecognized host outside the supported surfaces" do
    context = HostContextResolver.call(Request.new("example.test"))

    assert_equal :unknown, context.surface
  end

  test "retired base network and developer hosts are outside the supported surfaces" do
    %w(base.net.localhost base.dev.localhost).each do |host|
      context = HostContextResolver.call(Request.new(host))

      assert_equal :unknown, context.surface
    end
  end
end
