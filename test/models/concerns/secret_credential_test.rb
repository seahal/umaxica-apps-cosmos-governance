# typed: false
# frozen_string_literal: true

require "test_helper"

class SecretCredentialTest < ActiveSupport::TestCase
  test "uses the fixed secret credential length" do
    assert_equal 32, SecretCredential::SECRET_PASSWORD_LENGTH
  end

  test "rejects an unknown secret credential status" do
    assert_raises(KeyError) { OperatorSecretCredential.status_id_for(:unknown) }
  end
end
