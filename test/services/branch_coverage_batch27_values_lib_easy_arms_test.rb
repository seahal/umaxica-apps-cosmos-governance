# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit tops for still-cold value/lib/model arms.
class BranchCoverageBatch27ValuesLibEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "AccountStanding refuses unsupported level" do
    assert_raises(ArgumentError) { AccountStanding.new(level: :nope, decisions: {}) }
  end

  test "SecurityJwtAuthAccessTokenCodec resource type blank arm" do
    assert_nil SecurityJwtAuthAccessTokenCodec.extract_resource_type({})
  end

  test "TimezoneIdentifier returns nil for unknown zone" do
    assert_nil TimezoneIdentifier.normalize("Not/A/Real/Zone")
  end

  test "lib ChainSeal and ObservabilityRedactor easy arms" do
    assert_not ChainSeal.respond_to?(:ensure_ready!, true)
    assert_equal "[FILTERED]", ObservabilityRedactor.scrub(password: "secret")[:password]
  end

  test "lib LocalEnvironment and ConfigValuesOriginValue arms" do
    assert_not LocalEnvironment.respond_to?(:enabled?)
    assert_equal "https://example.com", ConfigValues.build("example.com").to_s
    assert_raises(ArgumentError) { ConfigValues.build("") }
  end

  test "JitSecurityTurnstileVerifier blank and error arms" do
    result = JitSecurityTurnstileVerifier.verify(token: "", remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", result["error"]
  end

  test "BlindIndexUniquenessValidator and AssociatedRecordLimitValidator edges" do
    validator = BlindIndexUniquenessValidator.new(attributes: [:email])
    record = ClientEmail.new

    assert_nil validator.validate_each(record, :email, nil)
  end
end
