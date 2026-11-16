# typed: false
# frozen_string_literal: true

# Finds the latest registration bound to a Governance registration cookie, with its completion receipt
# when it completed. Used only to re-issue the current answer for a replayed handoff.
class ClientRegistrationBrowserQuery
  Found = Data.define(:registration, :completion)

  def self.call(browser_secret_digest:)
    return nil unless browser_secret_digest.is_a?(String)

    registration = ClientRegistration.where(browser_secret_digest:).order(:id).last
    return nil unless registration

    completion =
      if registration.completed?
        ClientRegistrationCompletion.preload(:client).find_by!(sign_up_flow_ref: registration.public_id)
      end
    Found.new(registration:, completion:)
  end
  public_class_method :call
end
