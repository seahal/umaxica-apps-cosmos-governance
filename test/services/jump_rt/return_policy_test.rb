# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpRtReturnPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "normalize_origin rejects invalid uri classes" do
    ["not a url", "ftp://example.test", "https://user:pass@example.test", "https://"].each do |origin|
      assert_nil JumpRtReturnPolicy.normalize_origin(origin), origin
    end
  end

  test "normalize_origin rejects paths queries and fragments" do
    ["https://example.test/", "https://example.test/path", "https://example.test?x=1",
     "https://example.test#fragment",].each do |origin|
      assert_nil JumpRtReturnPolicy.normalize_origin(origin), origin
    end
  end

  test "normalize_origin canonicalizes case and default ports" do
    assert_equal "https://example.test", JumpRtReturnPolicy.normalize_origin("https://EXAMPLE.TEST:443")
    assert_equal "http://example.test", JumpRtReturnPolicy.normalize_origin("http://EXAMPLE.TEST:80")
    assert_equal "https://example.test:8443", JumpRtReturnPolicy.normalize_origin("https://EXAMPLE.TEST:8443")
  end

  test "no cross-surface Jump return edges are configured after the surface reset" do
    assert_empty JumpRtReturnPolicy::EDGE_CATALOG
    assert_empty JumpRtReturnPolicy::ALLOWED_EDGES

    [
      ["https://www.umaxica.app", "https://www.umaxica.app"],
      ["https://www.umaxica.org", "https://www.umaxica.app"],
      ["https://unregistered.example.test", "https://www.umaxica.app"],
    ].each do |source, destination|
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: destination, source: source)
    end
  end

  test "private and retired origins are denied in either direction" do
    [nil, "", "https://unregistered.example.test", "http://base.app.localhost", "https://127.0.0.1"].each do |origin|
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: "https://www.umaxica.app", source: origin)
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: origin, source: "https://www.umaxica.app")
    end
  end

  test "default_port_for returns each scheme port" do
    assert_equal 443, JumpRtReturnPolicy.default_port_for("https")
    assert_equal 80, JumpRtReturnPolicy.default_port_for("http")
  end
end
