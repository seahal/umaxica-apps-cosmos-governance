# frozen_string_literal: true

require "test_helper"

class MessageSerializationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "outbound payload rejects authenticated Marshal for each delivery purpose" do
    ["outbound.email.otp", "outbound.email.verification_token", "outbound.sms.delivery.v1"].each do |purpose|
      key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
        purpose, ActiveSupport::MessageEncryptor.key_len,
      )
      legacy = ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: Marshal)
      token = legacy.encrypt_and_sign("legacy payload", purpose: purpose)
      assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
        OutboundSensitivePayload.decrypt(token, purpose: purpose)
      end
    end
  end
end
