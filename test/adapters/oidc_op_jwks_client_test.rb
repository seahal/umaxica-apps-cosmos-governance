# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcOpJwksClientTest < ActiveSupport::TestCase
  test "malformed key identifiers are refused before a fetch" do
    fetcher_called = false
    client = OidcOpJwksClient.new(
      jwks_uri: "https://keys.example.test/.well-known/jwks.json",
      fetcher: lambda {
        fetcher_called = true
        { "keys" => [] }
      },
      limiter: nil,
    )

    result = client.lookup("\u0001invalid")

    assert_predicate result, :invalid?
    assert_equal "malformed_kid", result.reason
    assert_not fetcher_called
  end
end
