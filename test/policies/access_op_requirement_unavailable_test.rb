# frozen_string_literal: true

require "test_helper"

class AccessOpRequirementUnavailableTest < ActiveSupport::TestCase
  test "client passkey management cannot manufacture an OP session requirement" do
    policy = ClientPasskeyPolicy.new(ClientPasskey.new, user: Client.new)

    assert_raises(AccessOpDataUnavailableError) { policy.management_requirement(token: nil) }
    assert_raises(AccessOpDataUnavailableError) { policy.management_authorized?(token: nil, now: Time.current) }
  end

  test "operator passkey management cannot manufacture an OP session requirement" do
    policy = OperatorPasskeyPolicy.new(OperatorPasskey.new, user: Operator.new)

    assert_raises(AccessOpDataUnavailableError) { policy.management_requirement(token: nil) }
    assert_raises(AccessOpDataUnavailableError) { policy.management_authorized?(token: nil, now: Time.current) }
  end

  test "client contacts require an unavailable Access registration contract" do
    email = ClientEmailPolicy.new(ClientEmail.new, user: Client.new)
    telephone = ClientTelephonePolicy.new(ClientTelephone.new, user: Client.new)

    assert_raises(AccessOpDataUnavailableError) { email.credential_registration_requirement(token: nil) }
    assert_raises(AccessOpDataUnavailableError) { telephone.credential_registration_requirement(token: nil) }
  end

  test "operator contacts require an unavailable Access registration contract" do
    email = OperatorEmailPolicy.new(OperatorEmail.new, user: Operator.new)
    telephone = OperatorTelephonePolicy.new(OperatorTelephone.new, user: Operator.new)

    assert_raises(AccessOpDataUnavailableError) { email.credential_registration_requirement(token: nil) }
    assert_raises(AccessOpDataUnavailableError) { telephone.credential_registration_requirement(token: nil) }
  end

  test "organization invitation validation cannot query retired OP storage" do
    assert_raises(AccessOpDataUnavailableError) do
      OrgRegistrationPolicy.validate!(invitation_code: "unavailable")
    end
  end
end
