# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class HostNameNormalizationTest < ActiveSupport::TestCase
  test "normalizes a standard host" do
    assert_equal "example.com", HostNameNormalization.normalize("https://Example.Com/")
  end

  test "returns nil for blank input" do
    assert_nil HostNameNormalization.normalize(nil)
    assert_nil HostNameNormalization.normalize("")
    assert_nil HostNameNormalization.normalize("   ")
  end

  test "falls back to host extraction when URI parsing fails" do
    assert_equal "example.com", HostNameNormalization.normalize("example.com:8080/path")
  end

  test "returns nil for unparseable host with invalid URI" do
    result = HostNameNormalization.normalize("\x00")

    assert_nil result
  end

  test "rescues from URI parse failure and falls back to host extraction" do
    result = HostNameNormalization.normalize("foo bar")

    assert_equal "foo bar", result
  end
end
