# typed: false
# frozen_string_literal: true

require "test_helper"

class BrowserSessionSecurityContextTest < ActiveSupport::TestCase
  test "is active when each bound session is active" do
    browser_session = Struct.new(:usable?, :public_id).new(true, "browser-session")
    root_token = Struct.new(:active_status?, :public_id).new(true, "root-session")
    rp_session = Struct.new(:active?, :public_id).new(true, "rp-session")
    context = BrowserSessionSecurityContext.new(
      resource: Object.new,
      browser_session: browser_session,
      root_token: root_token,
      rp_session: rp_session,
      access_payload: {},
    )

    assert_predicate context, :active?
    assert_equal "root-session", context.root_session_public_id
    assert_equal "rp-session", context.rp_session_public_id
  end
end
