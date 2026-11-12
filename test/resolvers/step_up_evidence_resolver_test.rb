# frozen_string_literal: true

require "test_helper"

class StepUpEvidenceResolverTest < ActiveSupport::TestCase
  fixtures :clients, :operators
  self.fixture_table_names = %w(clients operators)

  setup do
    @actor = clients(:one)
    @cell = RpCellBinding.fetch("rp_base_app")
    @issuer = OidcIssuer.for_resource_type("client")
    @subject = OidcSubject.for(@actor, resource_type: "client")
    @sid = SecureRandom.alphanumeric(21)
    @now = RpBaseAppRecord.database_now
    @rp_session = seed_rp_cell_session(
      cell: @cell,
      issuer: @issuer,
      subject: @subject,
      sid: @sid,
      absolute_expires_at: @now + 1.hour,
    )
    binding = RpBaseAppOpSessionBinding.includes(identity_binding: :principal).find(@rp_session.op_session_binding_id)
    @principal = binding.identity_binding.principal
    @payload = {
      "iss" => @issuer,
      "aud" => [OidcClientRegistry.find!(@cell.client_id).aud],
      "sid" => @sid,
      "sub" => @subject,
      "client_id" => @cell.client_id,
      AuthenticationContextValue::CLAIM => AuthenticationContextValue::NORMAL_KEY,
      "acr" => StepUpEvidenceResolver::STEP_UP_ACR,
      "amr" => ["passkey"],
      "auth_time" => @now.to_i - 1,
      "exp" => @now.to_i + 60,
      "jti" => SecureRandom.hex(16),
    }
    @access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: @principal,
      rp_session: @rp_session,
      payload: @payload,
      security_context: nil,
    )
  end

  test "accepts a verified local RP event immediately inside the five-minute window" do
    access_state = @access_state.with(
      payload: @payload.merge("auth_time" => @now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS + 1),
    )

    RpBaseAppRecord.stub(:database_now, @now) do
      evidence = StepUpEvidenceResolver.call(access_state:, actor: @actor, cell: @cell)

      assert_instance_of StepUpEvidenceValue, evidence
      assert_equal @sid, evidence.sid
      assert_equal @subject, evidence.sub
    end
  end

  test "rejects a local event at the five-minute boundary, in the future, or after token expiry" do
    boundary = @access_state.with(
      payload: @payload.merge("auth_time" => @now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS),
    )
    future = @access_state.with(payload: @payload.merge("auth_time" => @now.to_i + 1))
    expired = @access_state.with(payload: @payload.merge("exp" => @now.to_i))

    RpBaseAppRecord.stub(:database_now, @now) do
      assert_nil StepUpEvidenceResolver.call(access_state: boundary, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: future, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: expired, actor: @actor, cell: @cell)
    end
  end

  test "rejects a local event for another grant, subject, audience, or malformed method attribution" do
    wrong_sid = @access_state.with(payload: @payload.merge("sid" => SecureRandom.alphanumeric(21)))
    wrong_subject = @access_state.with(payload: @payload.merge("sub" => "another-subject"))
    wrong_audience = @access_state.with(payload: @payload.merge("aud" => ["another-client"]))
    malformed_amr = @access_state.with(payload: @payload.merge("amr" => "passkey"))

    RpBaseAppRecord.stub(:database_now, @now) do
      assert_nil StepUpEvidenceResolver.call(access_state: wrong_sid, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: wrong_subject, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: wrong_audience, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: malformed_amr, actor: @actor, cell: @cell)
    end
  end

  test "rejects step-up evidence in an ORG standby authentication context" do
    actor = operators(:one)
    cell = RpCellBinding.fetch("rp_base_org")
    issuer = OidcIssuer.for_resource_type("operator")
    subject = OidcSubject.for(actor, resource_type: "operator")
    sid = SecureRandom.alphanumeric(21)
    now = RpBaseOrgRecord.database_now
    session = seed_rp_cell_session(
      cell:, issuer:, subject:, sid:, absolute_expires_at: now + 1.hour,
    )
    binding = RpBaseOrgOpSessionBinding.includes(identity_binding: :principal).find(session.op_session_binding_id)
    client = OidcClientRegistry.find!(cell.client_id)
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: binding.identity_binding.principal,
      rp_session: session,
      payload: {
        "iss" => issuer,
        "aud" => [client.aud],
        "sid" => sid,
        "sub" => subject,
        "client_id" => cell.client_id,
        AuthenticationContextValue::CLAIM => AuthenticationContextValue::STANDBY_KEY,
        "acr" => StepUpEvidenceResolver::STEP_UP_ACR,
        "amr" => ["passkey"],
        "auth_time" => now.to_i - 1,
        "exp" => now.to_i + 60,
        "jti" => SecureRandom.hex(16),
      },
      security_context: nil,
    )

    RpBaseOrgRecord.stub(:database_now, now) do
      assert_nil StepUpEvidenceResolver.call(access_state:, actor:, cell:)
    end
  end
end
