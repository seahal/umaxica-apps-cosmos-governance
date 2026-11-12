# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutRenderedTitleSmokeTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "the Base public layout renders the configured brand title" do
    host! Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host
    get "/", params: { ri: "jp" }

    assert_response :success
    assert_select "title", "#{BRAND} (COM)"
  end
end
