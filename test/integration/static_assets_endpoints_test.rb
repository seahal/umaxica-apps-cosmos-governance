# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaticAssetsEndpointsTest < ActionDispatch::IntegrationTest
  ROBOTS_SURFACES = [
    {
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host,
      controller: "base/com/robots",
    },
    {
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
      controller: "base/app/robots",
    },
    {
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host,
      controller: "base/org/robots",
    },
  ].freeze

  SITEMAP_SURFACES = [
    {
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
      controller: "base/app/sitemaps",
    },
    {
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host,
      controller: "base/com/sitemaps",
    },
    {
      host: Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host,
      controller: "base/org/sitemaps",
    },
  ].freeze

  test "robots.txt is served on every configured surface" do
    ROBOTS_SURFACES.each do |surface|
      host! surface[:host]

      get "/robots.txt"

      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_includes response.body, "User-agent:"

      assert_equal "index", @request.params[:action]
      assert_equal surface[:controller], @request.params[:controller]
    end
  end

  test "sitemap.xml is served on every Base surface" do
    SITEMAP_SURFACES.each do |surface|
      host! surface[:host]

      get "/sitemap.xml"

      assert_response :success
      assert_equal "application/xml", response.media_type
      assert_includes response.body, "<urlset"

      assert_equal "show", @request.params[:action]
      assert_equal surface[:controller], @request.params[:controller]
    end
  end

  test "robots and sitemap responses set long cache headers" do
    host! Rails.configuration.x.boot_config.fetch(:hosts).base_service.host

    get "/sitemap.xml"

    cache_control = response.headers["Cache-Control"]

    assert_not_nil cache_control
    assert_match(/public/, cache_control)
    assert_match(/max-age=300/, cache_control)
    assert_match(/s-maxage=600/, cache_control)
    assert_equal "600", response.headers["Surrogate-Control"][("max-age=".size)..]
  end
end
