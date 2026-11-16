# typed: false
# frozen_string_literal: true

require "test_helper"

class BrandTldTest < ActiveSupport::TestCase
  test "a host with no brand edition among its labels is refused rather than guessed at" do
    helper = Object.new.extend(ApplicationHelper)
    helper.define_singleton_method(:request) { Struct.new(:host).new("example.test") }

    error = assert_raises(ArgumentError) { helper.brand_tld }

    assert_match(/Cannot derive a brand TLD/, error.message)
  end

  test "a host carrying a brand edition reports it in upper case" do
    { "www.umaxica.app" => "APP", "www.umaxica.com" => "COM" }
      .each do |host, expected|
        helper = Object.new.extend(ApplicationHelper)
        helper.define_singleton_method(:request) { Struct.new(:host).new(host) }

        assert_equal expected, helper.brand_tld, host
      end
  end
end
