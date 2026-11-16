# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class BaseAppSecretIndexTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  test "the secret collection fails closed when the Base APP owner context is unavailable" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    https!

    as_rp_cell("base-app-ww") do
      headers = as_user_headers(client, host:, select_available_app_persona: false)
      get base_app_secrets_path(ri: "jp"), headers: headers
    end

    assert_response :service_unavailable
    assert_nil response.location
    assert_not_includes response.body, client.public_id
  end
end
