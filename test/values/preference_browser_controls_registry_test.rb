# frozen_string_literal: true

require "test_helper"

class PreferenceBrowserControlsRegistryTest < ActiveSupport::TestCase
  API_THEME = "/api/v0/preferences/theme"
  API_COOKIE = "/api/v0/preferences/cookie"

  test "Base app, com, and org declare same-origin theme and cookie endpoints" do
    %w(app com org).each do |surface|
      controls = PreferenceBrowserControlsRegistry.fetch(family: "base", surface: surface)

      assert_equal API_THEME, controls.theme_endpoint_path, "base/#{surface} theme"
      assert_equal API_COOKIE, controls.cookie_endpoint_path, "base/#{surface} cookie"
    end
  end

  test "family and surface symbols resolve like strings" do
    assert_equal PreferenceBrowserControlsRegistry.fetch(family: "base", surface: "org"),
                 PreferenceBrowserControlsRegistry.fetch(family: :base, surface: :org)
  end

  test "every declared endpoint path is origin-relative" do
    PreferenceBrowserControlsRegistry::MATRIX.each_value do |surfaces|
      surfaces.each_value do |controls|
        [controls.theme_endpoint_path, controls.cookie_endpoint_path].compact.each do |path|
          assert_match %r{\A/(?!/)}, path
        end
      end
    end
  end

  test "an unknown family raises" do
    error = assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "unknown", surface: "app") }

    assert_match "unknown", error.message
  end

  test "a family/surface pair that does not exist raises" do
    [%w(unknown app), %w(base unknown), %w(tech org)].each do |family, surface|
      assert_raises(KeyError, "#{family}/#{surface}") do
        PreferenceBrowserControlsRegistry.fetch(family: family, surface: surface)
      end
    end
  end

  test "nil and empty family or surface raise" do
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: nil, surface: "app") }
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "", surface: "app") }
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "base", surface: nil) }
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "base", surface: "") }
  end
end
