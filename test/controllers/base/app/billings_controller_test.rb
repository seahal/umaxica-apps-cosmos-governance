# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::BillingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    host! @host
  end

  test "index declares private authentication" do
    assert_equal :private, Base::App::BillingsController.authentication_mode_for(:index)
  end

  test "index renders for signed in clients" do
    headers = as_user_headers(@client, host: @host)
    get base_app_billings_url(ri: "jp"), headers: headers

    assert_response :success
    assert_equal "base/app/billings/index", inertia_component
    assert_equal "Billings", inertia_props.fetch("title")
    assert_equal I18n.t("billings.signed_in_required"), inertia_props.fetch("description")
    assert_equal(
      { "label" => I18n.t("actions.up"), "href" => base_app_dashboard_path(ri: "jp") },
      inertia_props.fetch("up_link"),
    )
  end
end
