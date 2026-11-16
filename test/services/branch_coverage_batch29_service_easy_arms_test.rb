# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch29ServiceEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "SignRiskEnforcer and SignRiskEmitter blank context arms" do
    assert_nil SignRiskEnforcer.call(nil)
    assert_nil SignRiskEmitter.emit("test")
  end

  test "JumpRtReturnPolicy rejects non-HTTP origins" do
    assert_nil JumpRtReturnPolicy.normalize_origin("javascript:alert(1)")
  end

  test "lib JitSecurityJwtJtiGenerator and KeyMaterial arms" do
    jti = JitSecurityJwtJtiGenerator.generate

    assert_match(/\A[A-Za-z0-9_-]+\z/, jti)
    assert_equal JitSecurityJwtJtiGenerator.encoded_length(20), jti.length
    assert_equal({}, JitSecurityJwtKeyMaterial.parse_private_keyset(nil))
    assert_equal({}, JitSecurityJwtKeyMaterial.parse_private_keyset(""))
  end

  test "lib ObjectStorage and LocalEnvironment arms" do
    assert_raises(KeyError) { ObjectStorage::Environment.fetch("UMX_MISSING_OBJECT_STORAGE_KEY") }
    assert_nil LocalEnvironment.parse("# comment")[0]
    assert_nil LocalEnvironment.parse("")[0]
    assert_equal %w(FOO bar), LocalEnvironment.parse("FOO=bar")
  end

  test "AcmeSelectableContext inactive membership next [] arm" do
    helper = Class.new do
      include AcmeSelectableContext

      def config
        @config ||=
          begin
            c = Object.new
            c.define_singleton_method(:avatar_mode) { :none }
            c.define_singleton_method(:account_class) { Client }
            c
          end
      end

      def principal = nil

      def session = nil

      def accounts
        account = Object.new
        membership = Object.new
        membership.define_singleton_method(:active?) { false }
        account.define_singleton_method(:current_memberships) { [membership] }
        [account]
      end
    end.new

    assert_equal [], helper.selectable_candidates
  end
end
