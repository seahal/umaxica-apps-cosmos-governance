# typed: false
# frozen_string_literal: true

require "test_helper"

class Tech::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
  end

  test "the public landing page has no retired sign-in entry" do
    get tech_org_root_path(ri: "jp")

    assert_response :success
    assert_select "h1", I18n.t("tech.org.roots.heading")
    assert_select 'a[href="/sign"]', count: 0
  end
end
