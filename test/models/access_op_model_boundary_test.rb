# frozen_string_literal: true

require "test_helper"

class AccessOpModelBoundaryTest < ActiveSupport::TestCase
  test "Client signup finalization refuses unavailable Access proof before changing the actor" do
    client = Client.first!
    before = client.attributes
    assert_raises(AccessOpDataUnavailableError) { client.finalize_email_sign_up!(email: Object.new, flow: Object.new) }
    assert_raises(AccessOpDataUnavailableError) do
      client.finalize_telephone_sign_up!(telephone: Object.new, flow: Object.new)
    end
    assert_equal before, client.attributes
    assert_equal before, client.reload.attributes
  end

  test "email binding activation refuses unavailable proof and leaves its persisted binding unchanged" do
    email = ClientEmail.create!(user: Client.first!, address: "boundary@example.test", confirm_policy: true)
    before = email.attributes
    assert_raises(AccessOpDataUnavailableError) do
      email.finalize_registration_binding!(transaction: Object.new, code: "", session_ref: "")
    end
    assert_raises(AccessOpDataUnavailableError) { email.finalize_binding!(at: Time.current) }
    email.class.stub(:database_now, -> { raise ActiveRecord::ConnectionNotEstablished }) do
      assert_raises(AccessOpDataUnavailableError) { email.finalize_binding! }
    end
    assert_raises(AccessOpDataUnavailableError) { email.finalize_sign_up_binding!(flow: Object.new, session_nonce: "") }
    assert_raises(AccessOpDataUnavailableError) do
      email.mark_sign_up_verified!(flow: Object.new, session_nonce: "", code: "")
    end
    assert_equal before, email.attributes
    assert_equal before, email.reload.attributes
  end

  test "telephone binding activation refuses unavailable proof without changing the persisted contact" do
    telephone = ClientTelephone.create!(
      user: Client.first!, raw_number: "+819012345678", confirm_policy: true, confirm_using_mfa: true,
    )
    before = telephone.attributes
    assert_raises(AccessOpDataUnavailableError) do
      telephone.finalize_registration_binding!(transaction: Object.new, code: "", session_ref: "")
    end
    assert_raises(AccessOpDataUnavailableError) { telephone.finalize_binding!(at: Time.current) }
    telephone.class.stub(:database_now, -> { raise ActiveRecord::ConnectionNotEstablished }) do
      assert_raises(AccessOpDataUnavailableError) { telephone.finalize_binding! }
    end
    assert_raises(AccessOpDataUnavailableError) do
      telephone.finalize_sign_up_binding!(flow: Object.new, transaction: Object.new, session_nonce: "")
    end
    assert_equal before, telephone.attributes
    assert_equal before, telephone.reload.attributes
  end

  test "Operator email registration refuses unavailable proof without changing the persisted contact" do
    email = OperatorEmail.create!(staff: Operator.first!, address: "boundary@example.test", confirm_policy: true)
    before = email.attributes
    assert_raises(AccessOpDataUnavailableError) do
      email.finalize_email_registration!(transaction: Object.new, code: "", session_ref: "")
    end
    assert_equal before, email.attributes
    assert_equal before, email.reload.attributes
  end

  test "Operator telephone registration refuses unavailable proof without changing the persisted contact" do
    telephone = OperatorTelephone.create!(
      staff: Operator.first!, raw_number: "+819012345678", confirm_policy: true, confirm_using_mfa: true,
    )
    before = telephone.attributes
    assert_raises(AccessOpDataUnavailableError) do
      telephone.finalize_telephone_registration!(transaction: Object.new, code: "", session_ref: "")
    end
    assert_equal before, telephone.attributes
    assert_equal before, telephone.reload.attributes
  end

  test "registration completion verification refuses unavailable original flow without accepting substituted proof" do
    completion = ClientRegistrationCompletion.new
    before = completion.attributes
    assert_raises(AccessOpDataUnavailableError) { completion.verify_flow!(Object.new) }
    assert_equal before, completion.attributes
    assert_not completion.persisted?
  end

  test "Secret claim and retirement refuse unavailable proof before changing facts or writing audit" do
    credential = client_secret_credentials(:one)
    before = credential.attributes
    audit_count = ClientSecretAuditOutbox.count
    assert_raises(AccessOpDataUnavailableError) do
      credential.commit_sign_in_claim!(
        actor_context: Object.new, flow: Object.new, ceremony: Object.new,
        at: Time.current,
      )
    end
    assert_raises(AccessOpDataUnavailableError) do
      credential.commit_sign_in_retirement!(
        actor_context: Object.new, flow: Object.new, at: Time.current,
        purge_at: 1.day.from_now, successful: true, reason: "login_committed",
      )
    end
    assert_equal before, credential.attributes
    assert_equal audit_count, ClientSecretAuditOutbox.count
  end

  test "both appeal realms refuse resolution before mutating the appeal or its audit" do
    app_appeal = AppEnforcementAppeal.new
    org_appeal = OrgEnforcementAppeal.new
    app_before = app_appeal.attributes
    org_before = org_appeal.attributes
    assert_raises(AccessOpDataUnavailableError) do
      app_appeal.resolve!(reviewer_operator_public_id: "", resolution_code: "approved")
    end
    assert_raises(AccessOpDataUnavailableError) do
      org_appeal.resolve!(
        reviewer_operator_public_id: "", resolution_code: "rejected",
        step_up_token: Object.new, step_up_actor: Object.new, step_up_evidence: Object.new,
      )
    end
    assert_equal app_before, app_appeal.attributes
    assert_equal org_before, org_appeal.attributes
    assert_not app_appeal.persisted?
    assert_not org_appeal.persisted?
  end
end
