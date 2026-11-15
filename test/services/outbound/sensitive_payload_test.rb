# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Outbound
  class SensitivePayloadTest < ActiveSupport::TestCase
    test "encrypts and decrypts complete sms envelopes without embedding plaintext" do
      token = OutboundSensitivePayload.encrypt_sms_delivery(
        to: "+819012345678", title: "Verification", body: "Your code is 123456",
      )

      assert_not_includes token, "123456"
      assert_equal "Your code is 123456", OutboundSensitivePayload.decrypt_sms_delivery(token).fetch(:body)
    end
  end
end
