# frozen_string_literal: true

require "test_helper"

class AccessOwnedFeatureUnavailabilityTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "ClientSecretAuditOutboxPurger.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretAuditOutboxPurger.call!(record: nil) }
    end
  end

  test "ClientSecretClaimFinalizer.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretClaimFinalizer.call!(record: nil) }
    end
  end

  test "ClientSecretCredentialPurger.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretCredentialPurger.call!(record: nil) }
    end
  end

  test "ClientSecretIssuancePurger.call_omitted! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretIssuancePurger.call_omitted!(record: nil) }
    end
  end

  test "ClientSecretIssuancePurger.call_confirmed! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretIssuancePurger.call_confirmed!(record: nil) }
    end
  end

  test "ClientSecretIssuancePurger.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretIssuancePurger.call!(record: nil) }
    end
  end

  test "ClientSecretManualIssuanceInvalidator.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretManualIssuanceInvalidator.call!(record: nil) }
    end
  end

  test "ClientSecretManualIssuanceInvalidator.call_for_payload_failure! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) {
        ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(record: nil)
      }
    end
  end

  test "ClientSecretManualReattemptIssuer.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretManualReattemptIssuer.call!(record: nil) }
    end
  end

  test "ClientSecretManualReservationIssuer.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretManualReservationIssuer.call!(record: nil) }
    end
  end

  test "ClientSecretNameCommitter.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretNameCommitter.call!(record: nil) }
    end
  end

  test "ClientSecretPasskeyReservationIssuer.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretPasskeyReservationIssuer.call!(record: nil) }
    end
  end

  test "ClientSecretPresentationIssuer.prepare! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretPresentationIssuer.prepare!(record: nil) }
    end
  end

  test "ClientSecretPresentationIssuer.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretPresentationIssuer.call!(record: nil) }
    end
  end

  test "ClientSecretRevocationCommitter.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretRevocationCommitter.call!(record: nil) }
    end
  end

  test "ClientSecretSignInReceiptPurger.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretSignInReceiptPurger.call!(record: nil) }
    end
  end

  test "ClientSecretStorageConfirmationCommitter.call! refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { ClientSecretStorageConfirmationCommitter.call!(record: nil) }
    end
  end

  test "CredentialSecurityTransition.call refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { CredentialSecurityTransition.call(record: nil) }
    end
  end

  test "OperatorSecretCredentialsCreate.call refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { OperatorSecretCredentialsCreate.call(record: nil) }
    end
  end

  test "OperatorSecretCredentialsUpdate.call refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { OperatorSecretCredentialsUpdate.call(record: nil) }
    end
  end

  test "OperatorSecretCredentialsDestroy.call refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { OperatorSecretCredentialsDestroy.call(record: nil) }
    end
  end

  test "RetentionCrossDatabaseChildPurge.call refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { RetentionCrossDatabaseChildPurge.call(actor: Client.new) }
    end
  end

  test "OrgIamPrincipalCommitter.call refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { OrgIamPrincipalCommitter.call(record: nil) }
    end
  end

  test "OrgIamAuditedCommitter.call refuses unavailable authority" do
    assert_no_difference -> { ClientSecretCredential.count + OperatorSecretCredential.count } do
      assert_raises(AccessOpDataUnavailableError) { OrgIamAuditedCommitter.call(record: nil) }
    end
  end

  test "secret lifecycle refuses missing remote retention authority" do
    assert_raises(AccessOpDataUnavailableError) { ClientSecretLifecycleJob.perform_now }
  end
end
