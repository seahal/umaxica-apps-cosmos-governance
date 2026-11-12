# frozen_string_literal: true

require "test_helper"

class OwnershipTransferRequestTimestampValidationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "BureauOwnershipTransferRequest rejects missing requested_at" do
    request = BureauOwnershipTransferRequest.new(
      requested_at: Time.utc(2026, 11, 12),
      expires_at: Time.utc(2026, 11, 13),
    )
    request.requested_at = nil

    request.valid?

    assert request.errors.of_kind?(:requested_at, :blank)
  end

  test "BureauOwnershipTransferRequest rejects missing expires_at" do
    request = BureauOwnershipTransferRequest.new(
      requested_at: Time.utc(2026, 11, 12),
      expires_at: Time.utc(2026, 11, 13),
    )
    request.expires_at = nil

    request.valid?

    assert request.errors.of_kind?(:expires_at, :blank)
  end

  test "BureauOwnershipTransferRequest expiry before request instant" do
    instant = Time.utc(2026, 11, 12)
    request = BureauOwnershipTransferRequest.new(requested_at: instant, expires_at: instant - Rational(1, 1_000_000))

    request.valid?

    assert_not_empty request.errors[:expires_at]
  end

  test "BureauOwnershipTransferRequest expiry at request instant" do
    instant = Time.utc(2026, 11, 12)
    request = BureauOwnershipTransferRequest.new(requested_at: instant, expires_at: instant)

    request.valid?

    assert_not_empty request.errors[:expires_at]
  end

  test "BureauOwnershipTransferRequest expiry after request instant" do
    instant = Time.utc(2026, 11, 12)
    request = BureauOwnershipTransferRequest.new(requested_at: instant, expires_at: instant + Rational(1, 1_000_000))

    request.valid?

    assert_empty request.errors[:expires_at]
  end

  test "AgentOwnershipTransferRequest rejects missing requested_at" do
    request = AgentOwnershipTransferRequest.new(
      requested_at: Time.utc(2026, 11, 12),
      expires_at: Time.utc(2026, 11, 13),
    )
    request.requested_at = nil

    request.valid?

    assert request.errors.of_kind?(:requested_at, :blank)
  end

  test "AgentOwnershipTransferRequest rejects missing expires_at" do
    request = AgentOwnershipTransferRequest.new(
      requested_at: Time.utc(2026, 11, 12),
      expires_at: Time.utc(2026, 11, 13),
    )
    request.expires_at = nil

    request.valid?

    assert request.errors.of_kind?(:expires_at, :blank)
  end

  test "AgentOwnershipTransferRequest expiry before request instant" do
    instant = Time.utc(2026, 11, 12)
    request = AgentOwnershipTransferRequest.new(requested_at: instant, expires_at: instant - Rational(1, 1_000_000))

    request.valid?

    assert_not_empty request.errors[:expires_at]
  end

  test "AgentOwnershipTransferRequest expiry at request instant" do
    instant = Time.utc(2026, 11, 12)
    request = AgentOwnershipTransferRequest.new(requested_at: instant, expires_at: instant)

    request.valid?

    assert_not_empty request.errors[:expires_at]
  end

  test "AgentOwnershipTransferRequest expiry after request instant" do
    instant = Time.utc(2026, 11, 12)
    request = AgentOwnershipTransferRequest.new(requested_at: instant, expires_at: instant + Rational(1, 1_000_000))

    request.valid?

    assert_empty request.errors[:expires_at]
  end

  test "EnterpriseOwnershipTransferRequest rejects missing requested_at" do
    request = EnterpriseOwnershipTransferRequest.new(
      requested_at: Time.utc(2026, 11, 12),
      expires_at: Time.utc(2026, 11, 13),
    )
    request.requested_at = nil

    request.valid?

    assert request.errors.of_kind?(:requested_at, :blank)
  end

  test "EnterpriseOwnershipTransferRequest rejects missing expires_at" do
    request = EnterpriseOwnershipTransferRequest.new(
      requested_at: Time.utc(2026, 11, 12),
      expires_at: Time.utc(2026, 11, 13),
    )
    request.expires_at = nil

    request.valid?

    assert request.errors.of_kind?(:expires_at, :blank)
  end

  test "EnterpriseOwnershipTransferRequest expiry before request instant" do
    instant = Time.utc(2026, 11, 12)
    request = EnterpriseOwnershipTransferRequest.new(
      requested_at: instant,
      expires_at: instant - Rational(1, 1_000_000),
    )

    request.valid?

    assert_not_empty request.errors[:expires_at]
  end

  test "EnterpriseOwnershipTransferRequest expiry at request instant" do
    instant = Time.utc(2026, 11, 12)
    request = EnterpriseOwnershipTransferRequest.new(requested_at: instant, expires_at: instant)

    request.valid?

    assert_not_empty request.errors[:expires_at]
  end

  test "EnterpriseOwnershipTransferRequest expiry after request instant" do
    instant = Time.utc(2026, 11, 12)
    request = EnterpriseOwnershipTransferRequest.new(
      requested_at: instant,
      expires_at: instant + Rational(1, 1_000_000),
    )

    request.valid?

    assert_empty request.errors[:expires_at]
  end

  test "ClientPersonaOwnershipTransferRequest rejects missing requested_at" do
    request = ClientPersonaOwnershipTransferRequest.new(
      requested_at: Time.utc(2026, 11, 12),
      expires_at: Time.utc(2026, 11, 13),
    )
    request.requested_at = nil

    request.valid?

    assert request.errors.of_kind?(:requested_at, :blank)
  end

  test "ClientPersonaOwnershipTransferRequest rejects missing expires_at" do
    request = ClientPersonaOwnershipTransferRequest.new(
      requested_at: Time.utc(2026, 11, 12),
      expires_at: Time.utc(2026, 11, 13),
    )
    request.expires_at = nil

    request.valid?

    assert request.errors.of_kind?(:expires_at, :blank)
  end

  test "ClientPersonaOwnershipTransferRequest expiry before request instant" do
    instant = Time.utc(2026, 11, 12)
    request = ClientPersonaOwnershipTransferRequest.new(
      requested_at: instant,
      expires_at: instant - Rational(1, 1_000_000),
    )

    request.valid?

    assert_not_empty request.errors[:expires_at]
  end

  test "ClientPersonaOwnershipTransferRequest expiry at request instant" do
    instant = Time.utc(2026, 11, 12)
    request = ClientPersonaOwnershipTransferRequest.new(requested_at: instant, expires_at: instant)

    request.valid?

    assert_not_empty request.errors[:expires_at]
  end

  test "ClientPersonaOwnershipTransferRequest expiry after request instant" do
    instant = Time.utc(2026, 11, 12)
    request = ClientPersonaOwnershipTransferRequest.new(
      requested_at: instant,
      expires_at: instant + Rational(1, 1_000_000),
    )

    request.valid?

    assert_empty request.errors[:expires_at]
  end
end
