# frozen_string_literal: true

# Access owns OP state; its query and revocation APIs are not available to Governance yet.
class AccessOpDataUnavailableError < ApplicationError
  def initialize
    super("auth.rp_feature_unavailable", :service_unavailable)
  end
end
