# typed: false
# frozen_string_literal: true

require "test_helper"

# Browser-condition CSRF for the org administrative mutations. Forgery protection is on. A valid
# CSRF token passes the request guard and reaches the authentication boundary; it does not grant
# authentication or authorize the mutation. Expected results follow Rails' `:header_or_legacy_token`
# Origin and Fetch Metadata checks plus the Base legacy-token requirement on every unsafe request:
#
# - `Sec-Fetch-Site: same-origin` or `same-site` still requires a valid authenticity token;
# - `cross-site` is accepted only from a trusted origin (none is trusted for these endpoints);
# - a missing `Sec-Fetch-Site` falls back to the authenticity token;
# - an `Origin` header that differs from the request's own origin is rejected;
# - `Referer` is not consulted.
class OrgAdminCsrfTest < ActionDispatch::IntegrationTest
  fixtures :operators, :clients

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @granter = operators(:two)
    @client = clients(:one)
    @mutations = {
      support: [
        "support_session_revoke",
        -> { base_org_support_client_revocations_url(@client.public_id, host: @host) },
        -> { { reason_code: "security_incident", operation_id: SecureRandom.uuid } },
        -> { Chronicle.where(action: "support.session.revoked").count },
      ],
      iam: [
        "operator_capability",
        -> { base_org_iam_grants_url(host: @host) },
        lambda {
          { operator_public_id: @granter.public_id,
            capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
            reason_code: "duty_assignment",
            duration_days: "30",
            operation_id: SecureRandom.uuid, }
        },
        -> { OperatorCapabilityGrant.where(operator: @granter).count },
      ],
      enforcement: [
        "enforcement_case_apply",
        -> { base_org_support_app_enforcement_cases_url(host: @host) },
        lambda {
          { enforcement_case: { kind: "cooldown",
                                duration_mode: "timed",
                                visibility: "visible",
                                release_mode: "automatic",
                                effective_at: Time.current,
                                expires_at: 1.day.from_now,
                                reason_code: "abuse",
                                principal_public_id: @client.public_id, } }
        },
        -> { AppEnforcementCase.count },
      ],
    }
  end

  test "each mutation follows the Fetch Metadata and token contract" do
    @mutations.each do |name, (_scope, url, params, count)|
      rejected = [
        { "Sec-Fetch-Site" => "cross-site", "Origin" => "https://attacker.example" },
        { "Sec-Fetch-Site" => nil },
        { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://attacker.example" },
        { "Sec-Fetch-Site" => nil, "Referer" => "https://#{@host}/support" },
        { "Sec-Fetch-Site" => nil, "X-CSRF-Token" => "forged-token-value" },
      ]
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      begin
        # csrf_meta_tags renders only while forgery protection is on.
        get(base_org_root_url(ri: "jp", host: @host), headers: host_headers(@host))

        assert_response :success
        assert_predicate css_select("meta[name='csrf-token']").first&.[]("content"), :present?,
                         "#{name}: the page carries a CSRF token"

        rejected.each do |fetch_headers|
          assert_no_difference(count, "#{name}: #{fetch_headers.inspect} must be rejected") do
            post(url.call, params: params.call, headers: host_headers(@host).merge(fetch_headers))

            assert_response :unprocessable_content
          end
        end
        assert_no_difference(count, "#{name}: a JSON body gets no exemption") do
          post(
            url.call, params: params.call.to_json,
                      headers: host_headers(@host).merge("Sec-Fetch-Site" => nil, "Content-Type" => "application/json"),
          )

          assert_response :unprocessable_content
        end

        assert_no_difference(count, "#{name}: same-origin without a token is refused") do
          post(
            url.call, params: params.call,
                      headers: host_headers(@host).merge(
                        "Sec-Fetch-Site" => "same-origin",
                        "Referer" => "https://attacker.example/",
                      ),
          )

          assert_response :unprocessable_content
        end
      ensure
        ActionController::Base.allow_forgery_protection = original
      end
    end
  end

  test "a valid CSRF token passes the request guard without authenticating the request" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    begin
      get(base_org_root_url(ri: "jp", host: @host), headers: host_headers(@host))

      assert_response :success
      csrf_token = css_select("meta[name='csrf-token']").first["content"]

      assert_no_difference(-> { Chronicle.where(action: "support.session.revoked").count }) do
        post(
          base_org_support_client_revocations_url(@client.public_id, host: @host),
          params: { reason_code: "security_incident", operation_id: SecureRandom.uuid },
          headers: host_headers(@host).merge("Sec-Fetch-Site" => nil, "X-CSRF-Token" => csrf_token),
        )
      end

      assert_response :unauthorized
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
  end
end
