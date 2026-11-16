# typed: false
# frozen_string_literal: true

require "test_helper"

# Creating a preference writes rows that reference fixed-id lookup tables (status, audit
# level, audit event, binding method, DBSC status). When a lookup row is missing, the
# first request that creates a preference restores it instead of failing on a foreign key.
class PreferenceReferenceDefaultsRecoveryTest < ActionDispatch::IntegrationTest
  teardown do
    ApplicationRecord.clear_fixed_id_seed_cache!
  end

  test "an app preference write restores a missing audit level and records its audit entry" do
    AppPreferenceChronicle.delete_all
    AppPreferenceChronicleLevel.where(id: AppPreferenceChronicleLevel::INFO).delete_all
    ApplicationRecord.clear_fixed_id_seed_cache!

    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: AppPreferenceRegionOption::US } }

    assert_response :redirect
    assert AppPreferenceChronicleLevel.exists?(id: AppPreferenceChronicleLevel::INFO)
    preference = AppPreference.order(:created_at).last

    assert_predicate preference, :present?
    assert AppPreferenceChronicle.exists?(
      subject_id: preference.id.to_s, subject_type: "AppPreference",
      event_id: AppPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
    )
  end

  test "an org preference write restores a missing audit level on the audit writer" do
    OrgPreferenceChronicle.delete_all
    OrgPreferenceChronicleLevel.where(id: OrgPreferenceChronicleLevel::INFO).delete_all
    ApplicationRecord.clear_fixed_id_seed_cache!

    host! ENV.fetch("PRIVATE_BASE_STAFF_URL")
    patch base_org_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: OrgPreferenceRegionOption::US } }

    assert_response :redirect
    assert OrgPreferenceChronicleLevel.exists?(id: OrgPreferenceChronicleLevel::INFO)
    preference = OrgPreference.order(:created_at).last

    assert_predicate preference, :present?
    assert OrgPreferenceChronicle.exists?(
      subject_id: preference.id.to_s, subject_type: "OrgPreference",
      event_id: OrgPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
    )
  end

  test "app and org audit write failures reject issuance and roll back new preferences" do
    cases = [
      [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), AppPreference, AppPreferenceChronicle,
       base_app_preference_region_path(ri: "jp"), AppPreferenceRegionOption::US,],
      [ENV.fetch("PRIVATE_BASE_STAFF_URL"), OrgPreference, OrgPreferenceChronicle,
       base_org_preference_region_path(ri: "jp"), OrgPreferenceRegionOption::US,],
    ]

    cases.each do |host, preference_class, audit_class, path, option_id|
      browser = open_session
      browser.host!(host)
      browser.https!

      audit_class.stub(:create!, ->(**) { raise ActiveRecord::RecordNotSaved, "audit unavailable" }) do
        assert_no_difference -> { preference_class.count } do
          browser.patch(path, params: { preference_region: { option_id: option_id } })
        end
      end

      assert_equal 503, browser.response.status
      assert_nil browser.cookies[PreferenceCookieName.anonymous_jwt]
    end
  end
end
