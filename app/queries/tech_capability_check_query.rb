# typed: false
# frozen_string_literal: true

# Resolves a Governance-issued Tech bearer to its active RP session and current Operator capability.
class TechCapabilityCheckQuery
  Decision =
    Data.define(:authenticated, :allowed) do
      def authenticated? = authenticated
    end

  CLIENT_ID = RpCellBinding.fetch("rp_tech_org").client_id
  RESOURCE_TYPE = "operator"

  class << self
    public

    def call(token:)
      verification = BaseApiAuthorityTokenVerifier.call(
        token:, expected_client_id: CLIENT_ID, expected_audience_resource_type: RESOURCE_TYPE,
      )
      return Decision.new(authenticated: false, allowed: false) unless verification.authenticated?

      subject = verification.claims.fetch("sub")
      public_id = OidcSubject.public_id_from(subject, resource_type: RESOURCE_TYPE)
      return Decision.new(authenticated: false, allowed: false) if public_id.blank?

      Operator.connection_class_for_self.connected_to(role: :writing) do
        operator = Operator.find_by(public_id:)
        next Decision.new(authenticated: false, allowed: false) unless operator
        next Decision.new(authenticated: false, allowed: false) unless
          secure_string_equal?(OidcSubject.for(operator, resource_type: RESOURCE_TYPE), subject)

        Decision.new(authenticated: true, allowed: operator.capability?(OperatorCapabilityGrant::TECH_ACCESS))
      end
    rescue ArgumentError
      Decision.new(authenticated: false, allowed: false)
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError => e
      raise AccessOpDataUnavailableError, "Tech capability authority is unavailable", cause: e
    end

    private

    def secure_string_equal?(left, right)
      left.is_a?(String) && right.is_a?(String) && left.bytesize == right.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(left, right)
    end
  end
end
