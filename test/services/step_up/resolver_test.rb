# frozen_string_literal: true

require "test_helper"

module StepUp
  class ResolverTest < ActiveSupport::TestCase
    test "legacy proof objects are unavailable before their properties can be mistaken for authority" do
      assert_raises(AccessOpDataUnavailableError) do
        StepUpResolver.call(token: Object.new, scope: "settings_email")
      end
    end

    test "absent proof never satisfies an active requirement or creates a usable token" do
      result = StepUpResolver.call(
        token: nil, scope: "settings_email",
        session_binding: "required-session", token_binding: "required-token",
      )

      assert_not result.satisfied?
      assert_not result.usable_token?
      assert_nil result.method
      assert_nil result.satisfied_at
      assert_nil result.expires_at
    end

    test "blank requested scopes retain the strict requirement contract without any fabricated proof" do
      [[nil, "scope is required"], ["", "scope must not be blank"]].each do |scope, message|
        error =
          assert_raises(StepUpRequirement::Invalid) do
            StepUpResolver.call(token: nil, scope: scope, session_binding: "session", token_binding: "token")
          end

        assert_equal message, error.message
      end
    end

    test "legacy AAL demands are rejected before unavailable proof interpretation" do
      %w(aal1 aal2 aal3).each do |aal|
        error =
          assert_raises(StepUpRequirement::Invalid) do
            StepUpResolver.call(token: Object.new, required_aal: aal)
          end

        assert_equal "legacy AAL requirements are unsupported", error.message
      end
    end

    test "active requirements cannot omit the session binding or turn off its binding requirement" do
      [true, false].each do |requires_binding|
        assert_raises(StepUpRequirement::Invalid) do
          StepUpRequirement.new(
            step_up_required: true, scope: "settings_email", allowed_methods: [:totp],
            phishing_resistant_required: false, user_verification_required: false,
            full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
            audience: "step_up:resolver", session_binding: nil, token_binding: "token_1",
            require_session_binding: requires_binding, actor_ref: "resolver", resource_ref: nil, tenant_ref: nil,
          )
        end
      end
    end
  end
end
