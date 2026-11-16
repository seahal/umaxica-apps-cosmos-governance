# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JumpRtKeyringTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @private_key = OpenSSL::PKey::RSA.generate(3072)
  end

  test "delegates active kid and private key lookup to the registry" do
    issuer = Struct.new(:id, :current_kid).new("issuer-id", "kid-123")

    JitSecurityJwtRegistry.stub(:surface, issuer) do
      JitSecurityJwtRegistry.stub(:private_key_for, @private_key) do
        assert_equal "kid-123", JumpRtKeyring.active_kid("BASE_APP")
        assert_equal @private_key, JumpRtKeyring.private_key("BASE_APP")
      end
    end
  end
end
