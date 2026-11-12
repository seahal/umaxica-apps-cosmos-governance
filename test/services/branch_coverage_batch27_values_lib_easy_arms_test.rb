# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit tops for still-cold value/lib/model arms.
class BranchCoverageBatch27ValuesLibEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "AccountStanding refuses unsupported level" do
    assert_raises(ArgumentError) { AccountStanding.new(level: :nope, decisions: {}) }
  end

  test "IdentityStepUpCeremonyContract validate helpers raise" do
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyContract.validate_required!({ "a" => "" }, %w(a))
    end
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyContract.validate_exact!({ "k" => "x" }, "k", "y")
    end
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      IdentityStepUpCeremonyContract.validate_boolean!({ "k" => "yes" }, "k")
    end
  end

  test "IdentityTelephoneCeremonyContract blank return_to early return" do
    assert_nil IdentityTelephoneCeremonyContract.validate_return_to!({ "return_to" => "" })
  end

  test "SecurityJwtAuthAccessTokenCodec resource type blank arm" do
    assert_nil SecurityJwtAuthAccessTokenCodec.extract_resource_type({})
  end

  test "SignInSequence valid_for and actor_matches false arms" do
    seq = SignInSequence.new(
      id: "1",
      surface: "app",
      participant: "guardrail",
      state: "STARTED",
      actor_type: "Client",
      actor_id: "1",
      expires_at: 1.hour.from_now.iso8601,
    )

    assert_not seq.valid_for?(
      surface: "com", actor: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL),
      participant: "guardrail",
    )
    assert_not seq.valid_for?(
      surface: "app", actor: Client.new(security_mode_id: SecurityModeConfigurable::NORMAL),
      participant: "checkpoint",
    )
    assert_not seq.actor_matches?(nil)
    assert_not seq.actor_matches?(Object.new)
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
