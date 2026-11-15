# frozen_string_literal: true

require "test_helper"

class BaseRpFrontChannelHttpClientInvariantTest < ActiveSupport::TestCase
  FLOW_PATHS = %w(
    app/controllers/base/app/sign/entries_controller.rb
    app/controllers/base/app/oidc/callbacks_controller.rb
    app/controllers/base/org/sign/entries_controller.rb
    app/controllers/base/org/oidc/callbacks_controller.rb
    app/controllers/concerns/oidc_rp_sign_entry.rb
    app/controllers/concerns/oidc_sso_initiator.rb
    app/controllers/concerns/oidc_callback.rb
    app/controllers/concerns/common_redirect.rb
    app/adapters/oidc_op_id_token_verifier.rb
    app/operations/rp_callback_committer.rb
  ).freeze
  FORBIDDEN_HTTP_CLIENTS = /\b(?:Faraday|Net::HTTP|HTTP\.get|OutboundHttp::Connection|OidcOpTokenClient|OidcOpRevocationClient|AvatarAuthorityClient|MembershipAuthorityClient|OrgAdminAuthorityClient|TechCapabilityClient)\b/

  test "Base sign-up and sign-in callers have no server-side HTTP client except the Visa JWKS lookup" do
    sources = FLOW_PATHS.index_with { |path| Rails.root.join(path).read }

    sources.each do |path, source|
      assert_no_match FORBIDDEN_HTTP_CLIENTS, source, path
    end
    assert_includes sources.fetch("app/controllers/concerns/oidc_callback.rb"), "OidcOpJwksClient.for_jwks_uri"
    assert_includes sources.fetch("app/adapters/oidc_op_id_token_verifier.rb"), "jwks_client.lookup"
    assert_not_includes sources.fetch("app/controllers/concerns/oidc_callback.rb"), "OidcOpTokenClient"
  end
end
