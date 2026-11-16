# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceGetEditCurrentBehaviorTest < ActionDispatch::IntegrationTest
  test "GET edit does not create a missing child preference row" do
    host! "base.app.localhost"

    get "/preference?ri=jp"

    assert_response :success
    preference = AppPreference.order(:created_at).last

    assert_not_nil preference

    AppPreferenceTheme.where(preference_id: preference.id).find_each(&:destroy!)

    assert_no_difference -> { AppPreferenceTheme.where(preference_id: preference.id).count } do
      get "/preference/theme/edit?ri=jp"
    end

    assert_response :success
  end

  test "GET edit still renders a default value when the child row is missing" do
    host! "base.app.localhost"

    get "/preference?ri=jp"

    assert_response :success
    preference = AppPreference.order(:created_at).last

    AppPreferenceTheme.where(preference_id: preference.id).find_each(&:destroy!)

    get "/preference/theme/edit?ri=jp"

    assert_response :success
    assert_nil AppPreferenceTheme.find_by(preference_id: preference.id)
  end

  test "PATCH selectable app preference updates through the screen action boundary" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::JP.to_s } }

    assert_response :redirect

    patch base_app_preference_currency_path(ri: "jp"),
          params: { preference_currency: { option_id: AppPreferenceCurrencyOption::USD.to_s } }

    assert_response :redirect

    claims = PreferenceToken.decode(cookies[PreferenceCookieName.anonymous_jwt], host:, jwt_issuer_id: "preference_app")
    preference = AppPreference.find_by!(public_id: claims.fetch("sub"))

    assert_equal AppPreferenceCurrencyOption::USD,
                 AppPreferenceCurrency.find_by!(preference_id: preference.id).option_id
  end
end
