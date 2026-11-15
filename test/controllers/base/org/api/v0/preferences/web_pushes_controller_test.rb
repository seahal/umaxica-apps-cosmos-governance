# frozen_string_literal: true

require "test_helper"

class Base::Org::Api::V0::Preferences::WebPushesControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    https!
    @headers = {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Origin" => "https://#{@host}",
      "Sec-Fetch-Site" => "same-origin",
    }
  end

  test "anonymous GET reports disabled without creating preference or browser state" do
    assert_no_difference [-> { OrgPreference.count }, -> { OrgPreferenceBrowserBinding.count },
                          -> { OrgPreferenceWebPush.count },] do
      get base_org_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }
    end

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal({ "web_push" => "disabled" }, response.parsed_body)
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_nil cookies[PreferenceBrowserBinding::COOKIE_NAME]
    assert_nil cookies[PreferenceCookieName.anonymous_jwt]
  end

  test "both accepted options persist behind the browser binding and GET never rotates their issuance" do
    %w(enabled disabled).each do |option|
      patch base_org_api_v0_preferences_web_push_path,
            params: { web_push: option }.to_json, headers: @headers

      assert_response :ok
      assert_equal "application/json", response.media_type
      assert_equal({ "web_push" => option }, response.parsed_body)
      claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
      preference = OrgPreference.find_by!(public_id: claims.fetch("sub"))
      binding = OrgPreferenceBrowserBinding.find_by!(preference_id: preference.id)
      stored = OrgPreferenceWebPush.find_by!(preference_id: preference.id)
      expected_id = (option == "enabled") ? OrgPreferenceWebPushOption::ENABLED : OrgPreferenceWebPushOption::DISABLED

      assert_equal expected_id, stored.option_id
      assert PreferenceBrowserBinding.matches?(cookies[PreferenceBrowserBinding::COOKIE_NAME], binding.digest)
      issuance = preference.attributes
      jwt = cookies[PreferenceCookieName.anonymous_jwt]

      assert_no_difference -> { OrgPreference.count } do
        get base_org_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }
      end

      assert_response :ok
      assert_equal({ "web_push" => option }, response.parsed_body)
      assert_equal issuance, preference.reload.attributes
      assert_equal jwt, cookies[PreferenceCookieName.anonymous_jwt]
      assert_not_includes response.headers["Set-Cookie"].to_s, "#{PreferenceBrowserBinding::COOKIE_NAME}="
    end
  end

  test "missing empty unsupported and non-string options return field errors without persistence" do
    submissions = [{}, { web_push: nil }, { web_push: "" }, { web_push: "ENABLED" },
                   { web_push: "unknown" }, { web_push: true }, { web_push: 0 },
                   { web_push: [] }, { web_push: {} },]

    submissions.each do |submission|
      assert_no_difference [-> { OrgPreference.count }, -> { OrgPreferenceBrowserBinding.count },
                            -> { OrgPreferenceWebPush.count },] do
        patch base_org_api_v0_preferences_web_push_path, params: submission.to_json, headers: @headers
      end

      assert_response :unprocessable_content
      assert_equal "application/problem+json", response.media_type
      assert_equal "urn:umaxica:problem:validation-failed", response.parsed_body.fetch("type")
      assert_equal ["/web_push"], response.parsed_body.fetch("errors").pluck("pointer")
      assert_nil cookies[PreferenceBrowserBinding::COOKIE_NAME]
      assert_nil cookies[PreferenceCookieName.anonymous_jwt]
    end
  end

  test "a foreign browser binding cannot read enabled state or change the original preference" do
    patch base_org_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json, headers: @headers

    assert_response :ok
    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
    preference = OrgPreference.find_by!(public_id: claims.fetch("sub"))
    generation = preference.jti
    binding = OrgPreferenceBrowserBinding.find_by!(preference_id: preference.id).digest
    cookies[PreferenceBrowserBinding::COOKIE_NAME] = PreferenceBrowserBinding.mint_value

    get base_org_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }

    assert_response :ok
    assert_equal({ "web_push" => "disabled" }, response.parsed_body)

    assert_no_difference -> { OrgPreference.count } do
      patch base_org_api_v0_preferences_web_push_path, params: { web_push: "disabled" }.to_json, headers: @headers
    end

    assert_response :forbidden
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:authorization-denied", response.parsed_body.fetch("type")
    assert_equal generation, preference.reload.jti
    assert_equal binding, OrgPreferenceBrowserBinding.find_by!(preference_id: preference.id).digest
    assert_equal OrgPreferenceWebPushOption::ENABLED,
                 OrgPreferenceWebPush.find_by!(preference_id: preference.id).option_id
  end

  test "a web push storage dependency failure returns a problem without rotating browser credentials" do
    patch base_org_api_v0_preferences_web_push_path, params: { web_push: "disabled" }.to_json, headers: @headers

    assert_response :ok
    jwt = cookies[PreferenceCookieName.anonymous_jwt]
    raw_binding = cookies[PreferenceBrowserBinding::COOKIE_NAME]
    claims = PreferenceToken.decode(jwt, host: @host)
    preference = OrgPreference.find_by!(public_id: claims.fetch("sub"))
    generation = preference.jti

    unavailable = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "storage unavailable" }

    OrgPreferenceWebPush.stub(:find_by, unavailable) do
      assert_no_difference -> { OrgPreference.count } do
        get base_org_api_v0_preferences_web_push_path, headers: { "Accept" => "application/json" }
      end
    end

    assert_response :service_unavailable
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
    assert_equal generation, preference.reload.jti
    assert_equal jwt, cookies[PreferenceCookieName.anonymous_jwt]
    assert_equal raw_binding, cookies[PreferenceBrowserBinding::COOKIE_NAME]
    assert_equal OrgPreferenceWebPushOption::DISABLED,
                 OrgPreferenceWebPush.find_by!(preference_id: preference.id).option_id
  end

  test "a write without the session CSRF token is refused before creating preference state" do
    prior_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    assert_no_difference [-> { OrgPreference.count }, -> { OrgPreferenceWebPush.count }] do
      patch(base_org_api_v0_preferences_web_push_path, params: { web_push: "enabled" }.to_json, headers: @headers)
    end

    assert_response :forbidden
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:csrf-verification-failed", response.parsed_body.fetch("type")
  ensure
    ActionController::Base.allow_forgery_protection = prior_forgery_protection
  end

  test "ORG actions fail closed below the two-passkey minimum while Access owns registration" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    prior_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    as_rp_cell("base-org-ww") do
      headers = as_staff_headers(actor, host: @host)
      headers.fetch("Cookie").split("; ").each do |pair|
        name, value = pair.split("=", 2)
        cookies[name] = Rack::Utils.unescape(value)
      end
      create_operator_passkeys =
        lambda do |count|
          OperatorPasskey.where(staff: actor).destroy_all
          count.times do
            OperatorPasskey.create!(
              staff: actor, webauthn_id: SecureRandom.urlsafe_base64(32), external_id: SecureRandom.uuid,
              public_key: "org-web-push-public-key", sign_count: 0, description: "ORG Web Push test passkey",
              status_id: OperatorPasskeyStatus::ACTIVE,
            )
          end
        end
      create_operator_passkeys.call(1)
      preference_count = OrgPreference.count
      get(base_org_preference_path(ri: "jp"))

      assert_response :service_unavailable
      assert_equal "application/json", response.media_type
      assert_equal({ "error" => I18n.t("auth.rp_feature_unavailable") }, response.parsed_body)
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_equal preference_count, OrgPreference.count

      create_operator_passkeys.call(2)

      get(base_org_preference_path(ri: "jp"))

      assert_response :ok
      csrf_token = response.parsed_body.at_css('meta[name="csrf-token"]').attr("content")

      assert_predicate csrf_token, :present?

      [1, 2, 3].each do |passkey_count|
        create_operator_passkeys.call(passkey_count)
        patch(
          base_org_api_v0_preferences_web_push_path,
          params: { web_push: "enabled" }.to_json,
          headers: @headers.merge("X-CSRF-Token" => csrf_token),
        )

        if passkey_count == 1
          assert_response :service_unavailable
          assert_equal "application/problem+json", response.media_type
          assert_equal "urn:umaxica:problem:service-unavailable", response.parsed_body.fetch("type")
          assert_equal 0, OrgPreferenceWebPush.count
        else
          assert_response :ok
          assert_equal({ "web_push" => "enabled" }, response.parsed_body)
          preference_claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host: @host)
          preference = OrgPreference.find_by!(public_id: preference_claims.fetch("sub"))

          assert_equal OrgPreferenceWebPushOption::ENABLED,
                       OrgPreferenceWebPush.find_by!(preference_id: preference.id).option_id
        end
      end
    end
  ensure
    ActionController::Base.allow_forgery_protection = prior_forgery_protection
  end
end
