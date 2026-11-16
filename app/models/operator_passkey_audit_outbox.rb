# typed: false
# frozen_string_literal: true

class OperatorPasskeyAuditOutbox < OrgZenithRecord
  include PasskeyAuditOutbox

  attr_readonly :event_uuid, :event_type, :surface, :external_id, :actor_ref, :operation_ref,
                :metadata, :occurred_at

  validates :event_uuid, :event_type, :surface, :external_id, :occurred_at, presence: true
  validates :event_uuid, uniqueness: true
  validates :operation_ref,
            uniqueness: { conditions: -> {
              where(event_type: %w(passkey.registered.signup passkey.registered.settings))
                .where.not(operation_ref: nil).where.not(operation_ref: "")
            } },
            if: -> {
              !operation_ref.nil? && operation_ref != "" && event_type.in?(
                %w(passkey.registered.signup
                   passkey.registered.settings),
              )
            }
  validates :event_type, inclusion: { in: PasskeyAuditOutbox::EVENT_TYPES }
  validates :surface, inclusion: { in: ["org"] }
end
