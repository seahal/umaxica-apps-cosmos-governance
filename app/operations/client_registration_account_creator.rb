# typed: false
# frozen_string_literal: true

# Creates the account rows of a completing registration inside the caller's app_zenith transaction:
# the ACTIVE Client (owner item O-5), the effective contact binding, the registered passkey when the
# method requires one, and the ClientRegistrationCompletion receipt. The caller then completes the
# registration through ClientRegistrationTransitionWriter in the same transaction.
class ClientRegistrationAccountCreator
  Credential = Data.define(:credential_id, :public_key, :sign_count, :backup_eligible, :backed_up)

  class << self
    public

    def call!(registration:, credential:)
      raise ArgumentError, "account creation requires the app_zenith transaction" unless
        ClientRegistration.lease_connection.transaction_open?

      now = Client.database_now
      client = Client.create!(
        status_id: ClientStatus::ACTIVE, security_mode_id: SecurityModeConfigurable::NORMAL,
        visibility_id: ClientVisibility::USER, birthdate: registration.birthdate,
        webauthn_user_handle: registration.webauthn_user_handle,
      )
      contact = create_contact!(registration:, client:, now:)
      ClientContactAuditOutbox.record!(
        contact_kind: registration.method_key, event_name: "finalized", owner_ref: client.public_id,
        contact_ref: contact.public_id, operation_ref: registration.public_id, actor_ref: client.public_id,
      )
      create_passkey!(registration:, client:, credential:)
      completion = ClientRegistrationCompletion.create!(
        public_id: PublicId.generate, client:, sign_up_flow_ref: registration.public_id,
        method_id: registration.method_id, completed_at: now,
      )
      completion
    end

    private

    def create_contact!(registration:, client:, now:)
      case registration.method_key
      when "email"
        ClientEmail.create!(
          user: client, address: registration.identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
          binding_finalized_at: now,
        )
      when "telephone"
        ClientTelephone.create!(
          user: client, number: registration.identifier,
          user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED, binding_finalized_at: now,
        )
      when "google", "apple"
        raise ArgumentError, "social registration completion is not accepted until its H1 contract is amended"
      else
        raise ArgumentError, "unsupported registration method #{registration.method_key.inspect}"
      end
    end

    def create_passkey!(registration:, client:, credential:)
      case registration.method_key
      when "telephone"
        raise ArgumentError, "telephone registration requires one passkey" unless credential.is_a?(Credential)

        passkey = ClientPasskey.create!(
          user: client, webauthn_id: credential.credential_id, public_key: credential.public_key,
          sign_count: credential.sign_count,
          backup_eligibility: credential.backup_eligible ? "eligible" : "ineligible",
          backup_observation: credential.backed_up ? "backed_up" : "not_backed_up",
        )
        PasskeyAuditOutbox.record_for!(
          passkey:, event_type: "passkey.registered.signup", surface: "app", actor_ref: client.public_id,
          operation_ref: registration.public_id,
        )
      when "email"
        raise ArgumentError, "email registration carries no Auth credential" unless credential.nil?
      else
        raise ArgumentError, "unsupported registration method #{registration.method_key.inspect}"
      end
    end
  end
end
