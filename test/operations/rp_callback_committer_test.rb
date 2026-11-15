# frozen_string_literal: true

require "test_helper"

class RpCallbackCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ISSUER = "https://visa.umaxica.app"

  setup do
    @cell = RpCellBinding.fetch("rp_base_app")
  end

  test "a verified callback creates a Base App local principal binding and session" do
    result = commit(subject: "base-app-subject", sid: "base-app-sid")

    assert_predicate result, :success?
    assert_instance_of RpBaseAppPrincipal, result.principal
    assert_instance_of RpBaseAppSession, result.session
    assert_equal "base-app-subject", RpBaseAppIdentityBinding.find_by!(subject: "base-app-subject").subject
    assert_equal "base-app-sid", RpBaseAppOpSessionBinding.find_by!(sid: "base-app-sid").sid
    evidence = RpBaseAppSessionAuthenticationEvidence.find_by!(rp_session_id: result.session.id)

    assert_equal "urn:umaxica:base:normal", evidence.acr
    assert_equal ["pwd"], evidence.amr
    assert_equal 1, RpBaseAppConsumedIdTokenJti.count
  end

  test "a repeated callback is refused without creating another local session" do
    first = commit(subject: "base-app-subject", sid: "base-app-sid")

    assert_equal :already_enrolled, commit(subject: "base-app-subject", sid: "base-app-sid").outcome
    assert_equal 1, RpBaseAppSession.where(op_session_binding_id: first.session.op_session_binding_id).count
  end

  test "a logged-out OP sid remains a tombstone for late callbacks" do
    RpBaseAppOpSessionBinding.create!(
      issuer: ISSUER, realm: "app", client_id: "base-app-ww", sid: "revoked-sid", revoked_at: Time.current,
    )

    result = commit(subject: "base-app-subject", sid: "revoked-sid")

    assert_equal :revoked, result.outcome
    assert_equal 0, RpBaseAppSession.count
    assert_nil RpBaseAppOpSessionBinding.find_by!(sid: "revoked-sid").identity_binding_id
  end

  test "an expired callback does not create local identity or session records" do
    assert_no_difference ["RpBaseAppPrincipal.count", "RpBaseAppIdentityBinding.count", "RpBaseAppSession.count"] do
      assert_equal :revoked, commit(
        subject: "expired-subject", sid: "expired-sid", absolute_expires_at: 1.second.ago,
      ).outcome
    end
  end

  test "an existing sid cannot be rebound to a different verified subject" do
    assert_predicate commit(subject: "first-subject", sid: "shared-sid"), :success?

    assert_no_difference ["RpBaseAppPrincipal.count", "RpBaseAppIdentityBinding.count", "RpBaseAppSession.count"] do
      result = commit(subject: "different-subject", sid: "shared-sid")

      assert_equal :binding_mismatch, result.outcome
    end
  end

  test "a consumed ID Token jti cannot create a second session" do
    digest = Digest::SHA256.hexdigest("one-id-token-jti")
    first = commit(subject: "base-app-subject", sid: "base-app-sid", jti_digest: digest)

    duplicate = commit(subject: "base-app-subject", sid: "base-app-sid", jti_digest: digest)

    assert_predicate first, :success?
    assert_equal :replayed, duplicate.outcome
    assert_equal 1, RpBaseAppConsumedIdTokenJti.count
  end

  test "a renewal extends the same expired session only when its public id matches the pending flow" do
    first = commit(subject: "base-app-subject", sid: "base-app-sid")
    first.session.update!(absolute_expires_at: 1.second.ago)

    renewed = commit(
      subject: "base-app-subject", sid: "base-app-sid", renewal_session_id: first.session.public_id,
    )

    assert_equal :renewed, renewed.outcome
    assert_equal first.session.id, renewed.session.id
    assert_operator renewed.session.absolute_expires_at, :>, Time.current
  end

  private

  def commit(subject:, sid:, absolute_expires_at: 1.hour.from_now, jti_digest: Digest::SHA256.hexdigest(SecureRandom.uuid),
             renewal_session_id: nil)
    RpCallbackCommitter.call(
      cell: @cell, issuer: ISSUER, subject:, sid:, absolute_expires_at:, id_token_jti_digest: jti_digest,
      id_token_expires_at: 2.minutes.from_now,
      authentication_evidence: { "acr" => "urn:umaxica:base:normal",
                                 "amr" => ["pwd"],
                                 "auth_time" => Time.current.to_i,
                                 "id_token_jti_digest" => jti_digest, },
      renewal_session_id:,
    )
  end
end
