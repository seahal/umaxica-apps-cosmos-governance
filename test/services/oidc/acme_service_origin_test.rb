# typed: false
# frozen_string_literal: true

require "test_helper"

module Oidc
  class AcmeServiceOriginTest < ActiveSupport::TestCase
    test "builds the fixed authorization and token endpoints from the OP origin" do
      origin = AcmeServiceOrigin.from("visa.umaxica.app", default_scheme: "https")

      assert_equal "https://visa.umaxica.app", origin.origin
      assert_equal "https://visa.umaxica.app/oauth/authorize", origin.authorization_endpoint
      assert_equal "https://visa.umaxica.app/oauth/authorize?client_id=base-app-ww",
                   origin.authorization_endpoint(query: { client_id: "base-app-ww" })
      assert_equal "https://visa.umaxica.app/oauth/token", origin.token_endpoint
    end

    test "treats origins with the same configured components as equal values" do
      origin = AcmeServiceOrigin.from("visa.umaxica.app", default_scheme: "https")
      equivalent = AcmeServiceOrigin.from("https://visa.umaxica.app:443", default_scheme: "http")

      assert_equal origin, equivalent
      assert_equal origin.hash, equivalent.hash
      assert_equal 1, Set.new([origin, equivalent]).size
    end

    test "preserves local OP ports and rejects paths, query strings and non-HTTP schemes" do
      local = AcmeServiceOrigin.from("http://visa.app.localhost:3001", default_scheme: "https")

      assert_equal "http://visa.app.localhost:3001/oauth/authorize", local.authorization_endpoint
      assert_raises(ArgumentError) { AcmeServiceOrigin.from("https://example.test/path", default_scheme: "https") }
      assert_raises(ArgumentError) { AcmeServiceOrigin.from("https://example.test?x=1", default_scheme: "https") }
      assert_raises(ArgumentError) { AcmeServiceOrigin.from("javascript:alert(1)", default_scheme: "https") }
    end

    test "requires a configured OP host and rejects an invalid configured origin" do
      assert_raises(AcmeServiceOrigin::ConfigurationUnavailable) do
        AcmeServiceOrigin.from_configured_host(nil, default_scheme: "https")
      end
      assert_raises(AcmeServiceOrigin::ConfigurationUnavailable) do
        AcmeServiceOrigin.from_configured_host("visa.umaxica.app/path", default_scheme: "https")
      end
    end
  end
end
