# frozen_string_literal: true

require "test_helper"

class Tech::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    @bundles = {}
    [
      ["tech-org-ww", RpTechOrgPrincipal, RpTechOrgIdentityBinding, RpTechOrgOpSessionBinding, RpTechOrgSession],
      ["base-org-ww", RpBaseOrgPrincipal, RpBaseOrgIdentityBinding, RpBaseOrgOpSessionBinding, RpBaseOrgSession],
    ].each do |client_id, principal_class, identity_class, binding_class, session_class|
      client = OidcClientRegistry.find!(client_id)
      issuer = OidcIssuer.for_client(client)
      subject = OidcSubject.for(@operator, resource_type: "operator")
      principal = principal_class.create!
      identity = identity_class.create!(
        principal: principal, issuer: issuer, realm: "org", client_id: client_id,
        subject: subject,
      )
      anchor = binding_class.create!(
        identity_binding: identity, issuer: issuer, realm: "org",
        client_id: client_id, sid: SecureRandom.uuid,
      )
      session = session_class.create!(
        op_session_binding: anchor, absolute_expires_at: 1.hour.from_now,
        installed_generation: 0,
      )
      now = Time.current.to_i
      token = JitSecurityJwtKeyring.encode(
        { "iss" => issuer,
          "sub" => subject,
          "aud" => [client_id],
          "client_id" => client_id,
          "sid" => anchor.sid,
          "jti" => SecureRandom.uuid,
          "scope" => "openid profile domain:operator",
          "iat" => now,
          "nbf" => now,
          "exp" => now + 600,
          "authn_ctx" => "normal", },
        typ: "at+jwt", issuer_id: "surface:BASE_ORG",
      )
      @bundles[client_id] = { token: token, session: session }
    end
    host! @host
    https!
  end

  test "verified Tech local principal is not a canonical Governance actor without Access" do
    bundle = @bundles.fetch("tech-org-ww")
    before = @operator.reload.attributes
    before_session = bundle.fetch(:session).reload.attributes.slice(
      "public_id", "op_session_binding_id",
      "absolute_expires_at", "installed_generation",
    )
    as_rp_cell("tech-org-ww") do
      install_base_rp_jwks_client(client_id: "tech-org-ww", access_token: bundle.fetch(:token))
      get tech_org_dashboard_path(ri: "jp"), headers: {
        "Cookie" => "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(bundle.fetch(:token))}; #{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{bundle.fetch(:session).public_id}",
      }

      assert_response :service_unavailable
      assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal before, @operator.reload.attributes
      assert_equal before_session,
                   bundle.fetch(:session).reload.attributes.slice(
                     "public_id", "op_session_binding_id", "absolute_expires_at",
                     "installed_generation",
                   )
    end
  end

  test "invalid JWT and wrong RP audiences are rejected before canonical actor lookup" do
    tech = @bundles.fetch("tech-org-ww")
    base = @bundles.fetch("base-org-ww")
    as_rp_cell("tech-org-ww") do
      install_base_rp_jwks_client(client_id: "tech-org-ww", access_token: tech.fetch(:token))
      ["invalid-token", base.fetch(:token)].each do |token|
        get tech_org_dashboard_path(ri: "jp"), headers: {
          "Cookie" => "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(token)}; #{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{tech.fetch(:session).public_id}",
        }

        assert_response :unauthorized
        assert_nil response.location
        assert_not_includes response.body, I18n.t("tech.org.dashboard.empty_state")
      end
    end
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    as_rp_cell("base-org-ww") do
      install_base_rp_jwks_client(client_id: "base-org-ww", access_token: base.fetch(:token))
      get base_org_dashboard_path(ri: "jp"), headers: {
        "Cookie" => "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(tech.fetch(:token))}; #{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{base.fetch(:session).public_id}",
      }

      assert_response :unauthorized
      assert_nil response.location
    end
  end

  test "Governance Tech policy still distinguishes a live capability from missing and expired grants" do
    assert_not TechAccessPolicy.new(@operator, user: @operator).apply(:show?)
    grant = OperatorCapabilityGrant.create!(
      operator: @operator, origin: "bootstrap",
      capability: OperatorCapabilityGrant::TECH_ACCESS, reason_code: "bootstrap",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )

    assert TechAccessPolicy.new(@operator, user: @operator).apply(:show?)
    grant.update!(expires_at: 1.second.ago)

    assert_not TechAccessPolicy.new(@operator, user: @operator).apply(:show?)
  end
end
