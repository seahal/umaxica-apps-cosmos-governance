# frozen_string_literal: true

require "test_helper"

class ClientSecretCredentialTest < ActiveSupport::TestCase
  test "claim identifiers are unique while unclaimed credentials retain NULL identifiers" do
    first = client_secret_credentials(:one)
    second = client_secret_credentials(:two)
    operation = SecureRandom.uuid
    flow = PublicId.generate
    claimed_at = Time.current
    ClientSecretCredential.where(id: first.id).update_all(
      claimed_at: claimed_at, claim_operation_id: operation,
      claim_sign_in_flow_ref: flow, claim_ceremony_session_id: 123,
    )
    first.reload

    [:claim_operation_id, :claim_sign_in_flow_ref].each do |field|
      duplicate = second.dup
      duplicate[field] = first[field]

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(field, :taken)
      attributes = {
        claimed_at: claimed_at,
        claim_operation_id: SecureRandom.uuid,
        claim_sign_in_flow_ref: PublicId.generate,
        claim_ceremony_session_id: 456,
      }
      attributes[field] = first[field]
      assert_raises(ActiveRecord::RecordNotUnique) do
        ClientSecretCredential.transaction(requires_new: true) do
          ClientSecretCredential.where(id: second.id).update_all(attributes)
        end
      end
    end
    assert_nil second.reload.claim_operation_id
    assert_nil second.claim_sign_in_flow_ref
  end

  test "name accepts 254 and 255 characters and rejects 256 missing and empty values" do
    credential = client_secret_credentials(:one)
    [254, 255].each do |length|
      credential.name = "n" * length

      assert_predicate credential, :valid?
    end
    ["n" * 256, "", nil].each do |name|
      credential.name = name

      assert_predicate credential, :invalid?
      assert_predicate credential.errors[:name], :any?
    end
  end

  test "credential owner and public identity cannot change after persistence" do
    credential = client_secret_credentials(:one)
    owner_id = credential.client_id
    reference = credential.public_id

    assert_equal reference, credential.to_param
    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.update!(client_id: clients(:two).id) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { credential.update!(public_id: SecureRandom.base58(21)) }
    assert_equal owner_id, credential.reload.client_id
    assert_equal reference, credential.public_id
  end

  test "candidate validation requires owner issuance and stored digests" do
    credential = client_secret_credentials(:one).dup
    credential.client = nil

    assert_predicate credential, :invalid?
    assert_predicate credential.errors[:client], :any?
    credential.client = clients(:one)
    credential.issuance = nil

    assert_predicate credential, :invalid?
    assert_predicate credential.errors[:issuance], :any?
    credential.issuance = client_secret_credentials(:one).issuance
    [nil, ""].each do |digest|
      credential.password_digest = digest

      assert_predicate credential, :invalid?
      assert_predicate credential.errors[:password_digest], :any?
    end
  end

  test "withdrawal revocation rejects an active Client without state changes or audit" do
    credential = client_secret_credentials(:one)
    now = Client.database_now
    assert_no_difference "ClientSecretAuditOutbox.count" do
      assert_raises(ClientSecretCredential::InvalidTransition) do
        credential.commit_withdrawal_revocation!(at: now, purge_at: now + 1.day)
      end
    end
    assert_nil credential.reload.revoked_at
    assert_equal Float::INFINITY, credential.discard_at
  end

  test "forced withdrawal revocation bypasses voluntary capability preservation" do
    credential = client_secret_credentials(:one)
    actor = credential.client
    actor.client_external_identities.delete_all
    actor.client_emails.delete_all
    actor.client_telephones.delete_all
    actor.client_passkeys.delete_all
    actor.client_totp_credentials.delete_all
    ClientSecretCredential.where(client_id: actor.id).where.not(id: credential.id).delete_all
    telephone = ClientTelephone.create!(
      user: actor,
      number: "+8190#{SecureRandom.random_number(10_000_000).to_s.rjust(7, "0")}",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      binding_finalized_at: ClientTelephone.database_now,
    )
    now = Client.database_now

    assert_equal [:secret], AuthenticationCredentialInventory.call(actor).usable_sign_in_capabilities
    assert_equal [:telephone], AuthenticationCredentialInventory.call(actor).contact_identifiers
    assert_not AuthMethodGuard.can_remove_secret_credential?(actor, credential)

    actor.update!(withdrawn_at: now, terminated_at: now)
    credential.commit_withdrawal_revocation!(at: now, purge_at: now + 1.day)

    assert credential.reload.revoked_at
    assert_kind_of Time, credential.discard_at
    assert_equal actor.id, telephone.reload.user_id
  end

  test "withdrawal retention rejects non-time and unordered boundaries before writing audit" do
    credential = client_secret_credentials(:one)
    now = Client.database_now
    credential.client.update!(withdrawn_at: now, terminated_at: now)
    invalid = [nil, "", 0, 1, [], {}, Float::INFINITY]
    boundaries = invalid.map { |value| [value, now + 1.day] } +
      invalid.map { |value| [now, value] } + [[now, now - 0.000001.seconds], [now, now]]

    boundaries.each do |at, purge_at|
      assert_no_difference "ClientSecretAuditOutbox.count" do
        assert_raises(ClientSecretCredential::InvalidTransition) do
          credential.commit_withdrawal_revocation!(at: at, purge_at: purge_at)
        end
      end
    end
    assert_nil credential.reload.revoked_at
    assert_equal Float::INFINITY, credential.discard_at
  end

  test "management revocation rejects invalid authority and timestamps without state changes" do
    credential = client_secret_credentials(:one)
    actor = credential.client
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    attributes = credential.attributes
    audit_count = ClientSecretAuditOutbox.count

    assert_raises(ClientSecretCredential::InvalidTransition) do
      credential.commit_management_revocation!(actor_context: nil, at: Client.database_now, purge_at: 1.day.from_now)
    end
    assert_raises(ClientSecretCredential::InvalidTransition) do
      credential.commit_management_revocation!(actor_context: context, at: nil, purge_at: 1.day.from_now)
    end

    assert_equal attributes, credential.reload.attributes
    assert_equal audit_count, ClientSecretAuditOutbox.count
  end

  test "storage confirmation refuses an unowned declaration inside its source transaction" do
    credential = ClientSecretCredential.new

    ClientSecretCredential.transaction do
      assert_raises(ClientSecretCredential::InvalidTransition) do
        credential.commit_storage_confirmation!(actor_context: ActorValuesContext.empty, at: Client.database_now)
      end
    end

    assert_nil credential.confirmed_at
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientSecretCredential)
  end
end
