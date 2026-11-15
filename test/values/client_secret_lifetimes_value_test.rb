# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientSecretLifetimesValueTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "issuance and proof lifetimes use their required positive seconds" do
    seconds_by_name = {
      "APP_SECRET_ISSUANCE_TTL_SECONDS" => "1",
      "APP_SECRET_PROOF_RETENTION_SECONDS" => "2592000",
    }

    ENV.stub(:fetch, ->(name) { seconds_by_name.fetch(name) }) do
      assert_equal 1.second, ClientSecretLifetimesValue.issuance_ttl
      assert_equal 30.days, ClientSecretLifetimesValue.proof_retention
    end
  end

  test "issuance lifetime refuses zero and negative durations" do
    ["0", "-1"].each do |seconds|
      error = nil

      ENV.stub(:fetch, ->(_name) { seconds }) do
        error = assert_raises(ArgumentError) { ClientSecretLifetimesValue.issuance_ttl }
      end

      assert_match(/must be positive/, error.message)
    end
  end

  test "proof retention refuses a missing configured duration" do
    error = nil

    ENV.stub(:fetch, ->(name) { raise KeyError, name }) do
      error = assert_raises(KeyError) { ClientSecretLifetimesValue.proof_retention }
    end

    assert_match(/APP_SECRET_PROOF_RETENTION_SECONDS/, error.message)
  end
end
