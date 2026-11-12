# frozen_string_literal: true

class StepUpAuditOutboxSourcesRegistry
  SOURCES = {
    "rp_base_app" => [
      RpStepUpAuditOutbox,
      "APP",
      RpStepUpAuditOutboxAttempt,
      RpStepUpAuditOutboxDeliveryState::PENDING,
      RpStepUpAuditOutboxDeliveryState::DELIVERED,
    ].freeze,
    "rp_base_org" => [
      RpBaseOrgStepUpAuditOutbox,
      "ORG",
      RpBaseOrgStepUpAuditOutboxAttempt,
      RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING,
      RpBaseOrgStepUpAuditOutboxDeliveryState::DELIVERED,
    ].freeze,
  }.freeze
end
