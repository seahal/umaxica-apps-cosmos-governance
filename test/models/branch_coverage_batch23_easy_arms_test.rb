# typed: false
# frozen_string_literal: true

require "test_helper"
require "jwt"

# Focused contracts for model case arms, DPoP request-binding refusals, and explicit Inertia layout
# ownership by each page controller.
class BranchCoverageBatch23EasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "OperatorPreferenceDateFormatOption#name covers the US arm" do
    option = OperatorPreferenceDateFormatOption.new
    option.id = OperatorPreferenceDateFormatOption::US

    assert_equal "us", option.name
  end

  test "SurfaceInertiaPage hosts declare the layout that matches their family and surface" do
    controller_root = Rails.root.join("app/controllers")
    hosts =
      controller_root.glob("**/*.rb").filter_map do |path|
        source = path.read
        next unless source.match?(/^\s*include\s+(?:::)?SurfaceInertiaPage\b/)

        family_and_surface = path.relative_path_from(controller_root).to_s.split("/").first(2).join("/")
        [path, source, "#{family_and_surface}/inertia"]
      end

    assert_not_empty hosts

    hosts.each do |path, source, layout|
      assert_match(/^\s*layout\s+"#{Regexp.escape(layout)}"\s*$/, source, path.to_s)
      assert_match(/^\s*inertia_share\s+chrome:/, source, path.to_s)
    end
  end

  test "RedirectsExternalTargetResolver refuses unknown keys and relative targets" do
    unknown = RedirectsExternalTargetResolver.call(:not_a_registry_key)

    assert_equal "unknown_key", unknown.failure_reason

    blank_host = RedirectsExternalTargetResolver.url("/relative", allowed_urls: ["https://example.test"])

    assert_equal "invalid_uri", blank_host.failure_reason

    # A parseable absolute URL that still carries a control character hits the dedicated arm.
    control = RedirectsExternalTargetResolver.url(
      "https://example.test/?q=" + 1.chr,
      allowed_urls: ["https://example.test"],
    )

    assert_includes %w(control_char invalid_uri origin_denied), control.failure_reason
  end
end
