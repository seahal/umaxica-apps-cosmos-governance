# typed: false
# frozen_string_literal: true

class ClientRetentionHoldStatus < AppPrincipalRecord
  include ReferenceRecord

  has_many :client_retention_holds, foreign_key: :status_id, inverse_of: :status,
                                    dependent: :restrict_with_error

  ACTIVE = 10
  RELEASED = 20
  EXPIRED = 30
  DEFAULTS = [ACTIVE, RELEASED, EXPIRED].freeze

  self.record_timestamps = false
end
