# typed: false
# frozen_string_literal: true

module Webauthn
  # Display-only observations received from the retained ceremony authority.
  class AuthenticatorMetadata
    COLUMNS = %i(aaguid transports authenticator_attachment provider_name metadata_source).freeze

    def self.permit(hash)
      symbolized = hash.present? ? hash.symbolize_keys : {}
      symbolized.slice(*COLUMNS).merge(
        backup_eligibility: eligibility(symbolized[:backup_eligible]),
        backup_observation: observation(symbolized[:backup_state]),
      )
    end
    public_class_method :permit

    def self.eligibility(value)
      case value
      when true then "eligible"
      when false then "ineligible"
      else "unknown"
      end
    end
    private_class_method :eligibility

    def self.observation(value)
      case value
      when true then "backed_up"
      when false then "not_backed_up"
      else "unknown"
      end
    end
    private_class_method :observation
  end
end
