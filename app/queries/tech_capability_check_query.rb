# typed: false
# frozen_string_literal: true

# Governance capability checks require Access to authenticate the external OP session.
# Authenticate the relying party first, then explicitly refuse the unavailable authority query.
class TechCapabilityCheckQuery
  CLIENT_ID = "tech-org-ww"

  class << self
    public

    # Returns true only for an explicit, current allow.
    def call(access_token:, client_assertion:, endpoint_uri:, host:)
      return false unless OidcClientRegistry.authenticate_assertion(
        CLIENT_ID, client_assertion,
        token_url: endpoint_uri,
      )

      raise AccessOpDataUnavailableError
    end
  end
end
