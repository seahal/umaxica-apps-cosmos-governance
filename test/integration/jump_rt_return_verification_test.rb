# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JumpRtReturnVerificationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @jump_private_key = OpenSSL::PKey::RSA.generate(3072)
    @jump_public_jwk = JWT::JWK.new(@jump_private_key, kid: "jump-test").export.stringify_keys.except(
      *JitSecurityJwtJwk::PRIVATE_FIELDS,
    ).merge(
      "alg" => "PS256",
      "use" => "sig",
    )
    @rails_private_key = OpenSSL::PKey::RSA.generate(3072)
    @rails_public_jwk = JWT::JWK.new(@rails_private_key, kid: "acme-app-test").export.stringify_keys.except(
      *JitSecurityJwtJwk::PRIVATE_FIELDS,
    ).merge(
      "alg" => "PS256",
      "use" => "sig",
    )
    @now = Time.current.change(usec: 0)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "Base-issued rt return is refused without an approved local source edge" do
    JumpRtKeyring.stub(:active_kid, "base-app-test") do
      JumpRtKeyring.stub(:private_key, @rails_private_key) do
        app_origin = base_app_origin
        rails_rt = JumpRtIssuer.call(
          namespace: "BASE_APP",
          url: "#{app_origin}/",
          dst: "internal",
          now: @now,
          jti: "rails-jti",
        )

        returned_location = stubbed_jump_location(rails_rt)
        returned_rt = Rack::Utils.parse_nested_query(URI.parse(returned_location).query).fetch("rt")
        prime_jump_jwks_cache

        https!
        prime_jump_jwks_cache
        get "#{app_origin}/", params: { rt: returned_rt }
      end
    end

    assert_response :bad_request
    assert_nil response.location
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
  end

  test "Base app rejects a signed Jump return without an approved source edge" do
    app_origin = base_app_origin
    https!
    token = sign_return_token(
      aud: app_origin,
      src: JumpRtSurface.issuer_origin("BASE_APP"),
      url: "#{app_origin}/?ok=1",
    )

    prime_jump_jwks_cache
    get "#{app_origin}/", params: { ok: "1", rt: token }

    assert_response :bad_request
    assert_nil response.location
  end

  test "Base app rejects invalid Jump return rt before its normal flow" do
    app_origin = base_app_origin
    https!

    get "#{app_origin}/", params: { rt: "not-a-jwt" }

    assert_response :bad_request
  end

  test "a signed return with a source path is rejected without redirecting" do
    app_origin = base_app_origin
    https!
    token = sign_return_token(
      aud: app_origin,
      src: "#{JumpRtSurface.issuer_origin("BASE_APP")}/unexpected",
      url: "#{app_origin}/?ok=1",
    )
    prime_jump_jwks_cache
    get "#{app_origin}/", params: { ok: "1", rt: token }

    assert_response :bad_request
    assert_nil response.location
  end

  test "rejected jump return logs do not include the rt token" do
    app_origin = base_app_origin
    https!
    token = "aaaaaaaa.bbbbbbbb.cccccccc"
    log_io = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_io)
    begin
      get("#{app_origin}/", params: { rt: token })
    ensure
      Rails.logger = previous_logger
    end
    joined = log_io.string

    assert_response :bad_request
    assert_includes joined, "jump_return.rejected"
    assert_not_includes joined, token
    assert_no_match(/rt=#{Regexp.escape(token)}/, joined)
  end

  # No local return source edge is approved. A valid signature alone must not reach the redirect
  # step or follow a downstream redirect parameter.
  test "an unapproved Jump return cannot follow a downstream redirect parameter" do
    origin = base_app_origin
    url = "#{origin}/?redirect_uri=https%3A%2F%2Fevil.example%2Fcb&ri=us"
    token = sign_return_token(aud: origin, src: JumpRtSurface.issuer_origin("BASE_APP"), url: url)
    prime_jump_jwks_cache
    host! URI.parse(origin).host
    https!
    get "/", params: { redirect_uri: "https://evil.example/cb", ri: "us", rt: token }

    assert_response :bad_request
    assert_nil response.location
  end

  test "a Jump return whose source edge is not approved is rejected even with a valid signature" do
    origin = base_app_origin
    token = sign_return_token(aud: origin, src: "https://jp.umaxica.com", url: "#{origin}/?ri=us")
    prime_jump_jwks_cache
    host! URI.parse(origin).host
    https!
    get "/", params: { ri: "us", rt: token }

    assert_response :bad_request
  end

  test "a signed Jump return cannot redirect when no source edge is approved" do
    origin = base_app_origin
    token = sign_return_token(
      aud: origin,
      src: JumpRtSurface.issuer_origin("BASE_APP"),
      url: "#{origin}/?ri=us&tag=b&tag=a&q=a%2Bb",
    )
    prime_jump_jwks_cache
    host! URI.parse(origin).host
    https!
    get "/?ri=us&tag=b&rt=#{token}&tag=a&q=a%2Bb"

    assert_response :bad_request
    assert_nil response.location
  end

  {
    "reordered pairs" => "tag=a&ri=us&tag=b&rt=%<token>s",
    "a second rt" => "ri=us&tag=b&tag=a&rt=%<token>s&rt=%<token>s",
    "a nested rt key" => "ri=us&tag=b&tag=a&rt=%<token>s&rt%%5Bx%%5D=1",
    "a duplicated reserved parameter" => "ri=us&tag=b&tag=a&next=%%2Fevil&next=%%2Fevil&rt=%<token>s",
  }.each do |label, query_format|
    test "a Jump-signed return with #{label} is rejected" do
      origin = base_app_origin
      token = sign_return_token(
        aud: origin,
        src: JumpRtSurface.issuer_origin("BASE_APP"),
        url: "#{origin}/?ri=us&tag=b&tag=a",
      )
      prime_jump_jwks_cache
      host! URI.parse(origin).host
      https!
      get "/?#{format(query_format, token: token)}"

      assert_response :bad_request
    end
  end

  test "a request whose only return token key is nested is rejected before the normal flow" do
    host! URI.parse(base_app_origin).host
    https!
    get "/?rt%5B%5D=a.b.c"

    assert_response :bad_request
  end

  test "a Jump return token on an unsafe Base request does not exempt it from CSRF" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    base_origin = base_app_origin
    token = sign_return_token(
      aud: base_origin,
      src: JumpRtSurface.issuer_origin("BASE_APP"),
      url: "#{base_origin}/api/v0/preferences/theme",
    )
    prime_jump_jwks_cache
    https!

    patch(
      "#{base_origin}/api/v0/preferences/theme?rt=#{Rack::Utils.escape(token)}",
      headers: {
        "Origin" => base_origin,
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_response :forbidden
    assert_nil response.location
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "Base app runs Jump return verification before set_current_context" do
    before_filters =
      Base::App::ApplicationController._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :before
      end

    assert_includes before_filters, :verify_jump_return_rt!
    assert_operator before_filters.index(:verify_jump_return_rt!), :<, before_filters.index(:set_current_context)
  end

  test "return verification concern does not register callbacks when included" do
    controller =
      Class.new(ActionController::Base) do # rubocop:disable Rails/ApplicationController
        include JumpRtReturnVerification
      end

    before_filters =
      controller._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :before
      end

    assert_not_includes before_filters, :verify_jump_return_rt!
  end

  private

  def stubbed_jump_location(rails_rt)
    rails_issuer = JumpRtSurface.issuer_origin("BASE_APP")
    payload, header = JWT.decode(
      rails_rt,
      JWT::JWK.import(@rails_public_jwk).public_key,
      true,
      algorithms: ["PS256"],
      iss: rails_issuer,
      verify_iss: true,
      aud: "https://jump.umaxica.net",
      verify_aud: true,
      verify_iat: false,
      verify_expiration: false,
      verify_not_before: false,
    )

    assert_equal "JWT", header.fetch("typ")
    assert_equal "base-app-test", header.fetch("kid")
    assert_equal rails_issuer, payload.fetch("iss")
    assert_equal 1, payload.fetch("schema")
    assert_equal "jump-redirect", payload.fetch("sub")
    assert_equal "internal", payload.fetch("dst")
    assert_equal "reuse", payload.fetch("rpl")
    assert_equal "#{base_app_origin}/", payload.fetch("url")

    return_rt = sign_return_token(
      aud: base_app_origin,
      src: payload.fetch("iss"),
      url: payload.fetch("url"),
      jti: "jump-jti",
      iat: @now.to_i,
      nbf: @now.to_i,
      exp: @now.to_i + 30,
    )
    "#{base_app_origin}/?#{Rack::Utils.build_query(rt: return_rt)}"
  end

  def prime_jump_jwks_cache
    jwks_url = "https://jump.umaxica.net/.well-known/jwks.json"
    cache_key = "jump_rt:return_jwks:#{Digest::SHA256.hexdigest(jwks_url)}"
    Rails.cache.write(cache_key, { "keys" => [@jump_public_jwk] }, expires_in: 30.seconds)
  end

  def sign_return_token(overrides = {})
    iat = @now.to_i
    payload = {
      schema: 1,
      iss: "https://jump.umaxica.net",
      aud: base_app_origin,
      sub: "jump-redirect",
      iat: iat,
      nbf: iat,
      exp: iat + 30,
      jti: "jump-return-jti",
      src: JumpRtSurface.issuer_origin("BASE_APP"),
      dst: "internal",
      rpl: "reuse",
      url: "#{base_app_origin}/",
    }.merge(overrides)

    JWT.encode(payload, @jump_private_key, "PS256", { typ: "JWT", kid: "jump-test" })
  end

  def base_app_origin
    JumpRtSurface.issuer_origin("BASE_APP")
  end
end
