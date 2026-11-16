# frozen_string_literal: true

require "test_helper"

class ContactCeremonySourceAuditTest < ActiveSupport::TestCase
  uses_transaction :test_concurrent_signed_email_finalization_keeps_one_effective_destination
  uses_transaction :test_concurrent_signed_telephone_finalization_keeps_one_effective_destination
  uses_transaction :test_concurrent_signed_finalization_keeps_one_effective_Contact_per_actor

  test "audit refuses a wrong actor role and an event without the corresponding Source binding fact" do
    owner = create_test_actor(Client)
    contact = ClientEmail.create!(user_id: owner.id, address: "audit-facts@example.test", confirm_policy: "1")
    [
      [ActorValuesContext.empty.with(subject: owner, actor_type: :operator, tld: :app, surface: :base),
       "actor context does not match Contact audit owner",],
      [ActorValuesContext.empty.with(subject: owner, actor_type: :client, tld: :app, surface: :base),
       "Contact audit does not match its committed binding fact",],
    ].each do |context, message|
      error =
        assert_raises(ArgumentError) do
          ClientEmail.transaction(requires_new: true) do
            ContactBindingAuditRecorder.call!(
              actor_context: context, actor: owner, contact: contact,
              operation_ref: SecureRandom.uuid, event_name: "finalized",
            )
          end
        end
      assert_equal message, error.message
      assert_not ClientContactAuditOutbox.exists?(contact_ref: contact.public_id)
    end
  end

  test "audit attribution refuses an actor from a different explicit context before Contact mutation" do
    owner = create_test_actor(Client)
    foreign = create_test_actor(Client)
    contact = ClientEmail.create!(user_id: owner.id, address: "wrong-context@example.test", confirm_policy: "1")
    context = ActorValuesContext.empty.with(subject: foreign, actor_type: :client, tld: :app, surface: :base)
    error =
      assert_raises(ArgumentError) do
        ClientEmail.transaction do
          ContactBindingAuditRecorder.call!(
            actor_context: context, actor: owner, contact: contact,
            operation_ref: SecureRandom.uuid, event_name: "finalized",
          )
        end
      end
    assert_equal "actor context does not match Contact audit owner", error.message
    assert_not contact.reload.binding_effective?
    assert_not ClientContactAuditOutbox.exists?(contact_ref: contact.public_id)
  end

  private

  def create_test_actor(actor_class)
    # Distinct high IDs keep cross-database foreign keys away from committed test/dev credentials.
    actor_class.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000),
    )
  end
end
