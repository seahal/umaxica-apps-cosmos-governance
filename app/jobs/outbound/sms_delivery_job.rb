# typed: false
# frozen_string_literal: true

require "aws-sdk-sns"

module Outbound
  class SmsDeliveryJob < ApplicationJob
    queue_as :default

    retry_on Aws::SNS::Errors::ServiceError, wait: :polynomially_longer, attempts: 5
    retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
    retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

    # A malformed or mixed payload is a permanent producer/configuration
    # failure. It must not be silently discarded because doing so hides a
    # delivery gap while preserving the no-plaintext-delivery boundary.
    discard_on ArgumentError, report: true

    public
    def perform(encrypted_payload: nil)
      payload = OutboundSensitivePayload.decrypt_sms_delivery(encrypted_payload)
      raise AccessOpDataUnavailableError if payload.key?(:otp_binding)

      OutboundSms.deliver_now(**payload.slice(:to, :title, :body))
    end
  end
end
