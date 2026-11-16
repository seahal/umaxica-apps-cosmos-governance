# frozen_string_literal: true

require "test_helper"

class RpCellSessionRevokerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @cell = RpCellBinding.fetch("rp_base_app")
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    @issuer = Oidc::AcmeServiceOrigin.from_configured_host(hosts.visa_service.host, default_scheme: "https").origin
  end

  test "a valid event revokes its local session and a repeated event is acknowledged once" do
    session_record = seed_rp_cell_session(
      cell: @cell, issuer: @issuer, subject: "base-app-revoker-subject", sid: "base-app-revoker-sid",
      absolute_expires_at: 1.hour.from_now,
    )
    now = Time.current.to_i
    payload = {
      "iss" => @issuer,
      "aud" => [@cell.client_id],
      "iat" => now,
      "exp" => now + 120,
      "jti" => "base-app-revoker-event",
      "sid" => "base-app-revoker-sid",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }

    assert_equal :revoked, RpCellSessionRevoker.call(cell: @cell, payload:)
    assert_predicate session_record.reload.revoked_at, :present?
    assert_equal :duplicate, RpCellSessionRevoker.call(cell: @cell, payload:)
    assert_equal 1, RpBaseAppEventReceipt.where(client_id: @cell.client_id).count
  end

  test "a logout for an unseen sid writes a tombstone that a late callback cannot reopen" do
    now = Time.current.to_i
    payload = {
      "iss" => @issuer,
      "aud" => [@cell.client_id],
      "iat" => now,
      "exp" => now + 120,
      "jti" => "base-app-unknown-sid-event",
      "sid" => "base-app-unknown-sid",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }

    assert_equal :revoked, RpCellSessionRevoker.call(cell: @cell, payload:)
    late = RpCallbackCommitter.call(
      cell: @cell, issuer: @issuer, subject: "base-app-late-subject", sid: payload.fetch("sid"),
      absolute_expires_at: 1.hour.from_now,
      id_token_jti_digest: Digest::SHA256.hexdigest("late-callback-jti"),
      id_token_expires_at: 2.minutes.from_now,
      authentication_evidence: {
        "acr" => "urn:umaxica:base:normal",
        "amr" => ["pwd"],
        "auth_time" => Time.current.to_i,
        "id_token_jti_digest" => Digest::SHA256.hexdigest("late-callback-jti"),
      },
    )

    assert_equal :revoked, late.outcome
    assert_predicate RpBaseAppOpSessionBinding.find_by!(sid: payload.fetch("sid")).revoked_at, :present?
  end

  test "a JTI reused for another sid is a conflict and does not create a second receipt" do
    now = Time.current.to_i
    payload = {
      "iss" => @issuer,
      "aud" => [@cell.client_id],
      "iat" => now,
      "exp" => now + 120,
      "jti" => "base-app-conflicting-event",
      "sid" => "base-app-first-sid",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
    RpCellSessionRevoker.call(cell: @cell, payload:)

    assert_raises(RpCellSessionRevoker::EventConflict) do
      RpCellSessionRevoker.call(cell: @cell, payload: payload.merge("sid" => "base-app-second-sid"))
    end
    assert_equal 1, RpBaseAppEventReceipt.where(client_id: @cell.client_id).count
    assert_nil RpBaseAppOpSessionBinding.find_by(sid: "base-app-second-sid")
  end

  test "payloads without the logout event or with a nonce are rejected" do
    now = Time.current.to_i
    payload = {
      "iss" => @issuer,
      "aud" => [@cell.client_id],
      "iat" => now,
      "exp" => now + 120,
      "jti" => "base-app-invalid-event",
      "sid" => "base-app-invalid-event-sid",
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }

    assert_raises(ArgumentError) do
      RpCellSessionRevoker.call(cell: @cell, payload: payload.except("events"))
    end
    assert_raises(ArgumentError) do
      RpCellSessionRevoker.call(cell: @cell, payload: payload.merge("nonce" => "unexpected"))
    end
    assert_empty RpBaseAppEventReceipt.where(client_id: @cell.client_id)
    assert_nil RpBaseAppOpSessionBinding.find_by(sid: payload.fetch("sid"))
  end
end
