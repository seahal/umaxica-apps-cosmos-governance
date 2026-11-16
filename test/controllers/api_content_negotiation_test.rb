# typed: false
# frozen_string_literal: true

require "test_helper"

# Base preference APIs keep JSON negotiation ahead of request verification.
class ApiContentNegotiationTest < ActionDispatch::IntegrationTest
  setup do
    host! Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
  end

  test "an html-only caller is refused before authentication" do
    get "/api/v0/preferences/theme", headers: { "Accept" => "text/html" }

    assert_response :not_acceptable
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:not-acceptable", response.parsed_body.fetch("type")
  end

  test "an absent Accept header accepts the JSON preference response" do
    get "/api/v0/preferences/theme", params: { ri: "jp" }

    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "a wrong request media type is refused before CSRF verification" do
    previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    patch(
      "/api/v0/preferences/theme",
      params: "not json",
      headers: { "Accept" => "application/json", "Content-Type" => "text/plain" },
    )

    assert_response :unsupported_media_type
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:unsupported-media-type", response.parsed_body.fetch("type")
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
  end
end
