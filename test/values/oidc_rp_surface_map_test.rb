# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRpSurfaceMapTest < ActiveSupport::TestCase
  test "first-party RP client ids are unique and named" do
    ids = OidcRpSurfaceMap.first_party_rp_client_ids

    assert_equal %w(base-app-ww base-org-ww tech-org-ww), ids
    assert_equal %w(base-app-ww base-org-ww), OidcRpSurfaceMap.base_self_rp_client_ids
    assert_predicate OidcRpSurfaceMap, :unique_client_ids?
  end

  test "every RP face maps to surface face and actor" do
    OidcRpSurfaceMap.rp_faces.each do |client_id, meta|
      # Every exact Client ID is `<family>-<realm>-<scope>`.
      expected_surface, expected_face, = client_id.split("-")

      assert_equal expected_surface, meta.fetch(:surface)
      assert_equal expected_face, meta.fetch(:face)
      assert_includes %w(client operator), meta.fetch(:actor)
      assert_equal "/oidc/callback", OidcRpSurfaceMap.callback_path_for(client_id)
      assert_equal "/sign/out/completion", OidcRpSurfaceMap.sign_out_path_for(client_id)
    end
  end

  test "step-up callbacks are registered only for Base self RPs" do
    OidcRpSurfaceMap::BASE_SELF_RP_CLIENT_IDS.each do |client_id|
      assert_equal "/verification/oidc/callback", OidcRpSurfaceMap.step_up_callback_path_for(client_id)
    end

    assert_raises(KeyError) { OidcRpSurfaceMap.step_up_callback_path_for("tech-org-ww") }
  end
end
