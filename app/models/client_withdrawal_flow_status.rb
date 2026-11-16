# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_withdrawal_flow_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientWithdrawalFlowStatus < AppPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  REQUESTED = 10
  CLOSING = 20
  DISCARDED = 30
  RECOVERED = 40
  TERMINATED = 100
  FAILED = 900
  DEFAULTS = [NOTHING, REQUESTED, CLOSING, DISCARDED, RECOVERED, TERMINATED, FAILED].freeze

  self.record_timestamps = false

  has_many :events_from_status, class_name: "ClientWithdrawalFlowEvent", foreign_key: :from_status_id,
                                inverse_of: :from_status, dependent: :restrict_with_error
  has_many :events_to_status, class_name: "ClientWithdrawalFlowEvent", foreign_key: :to_status_id,
                              inverse_of: :to_status, dependent: :restrict_with_error

  has_many :client_withdrawal_flows,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :status
end
