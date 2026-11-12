# typed: false
# frozen_string_literal: true

require "test_helper"

# Rendered title contract for the Base public surface.
class HtmlTitleContractTest < ActionDispatch::IntegrationTest
  BRAND = ENV.fetch("BRAND_NAME").upcase

  test "the public root uses the brand title alone" do
    host! Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host
    get "/", params: { ri: "jp" }

    assert_response :success
    title = response.parsed_body.at_css("title")&.text

    assert_equal "#{BRAND} (COM)", title
  end

  test "a non-root page places its localized title before the brand" do
    host! Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host
    get "/preference", params: { ri: "jp" }

    assert_response :success
    page_title = inertia_props.fetch("title")
    title = response.parsed_body.at_css("title")&.text

    assert_equal "#{page_title} — #{BRAND} (COM)", title
  end
end
