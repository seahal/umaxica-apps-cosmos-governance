# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcStateJwtTest < ActiveSupport::TestCase
  CLIENT_ID = "base-app-ww"

  test "a Base App state uses PS256 and carries its pending-flow key and path-only target" do
    state, jti = OidcStateJwt.issue(client_id: CLIENT_ID, target_link_uri: "/dashboard")
    result = OidcStateJwt.verify(client_id: CLIENT_ID, token: state)
    _payload, header = JWT.decode(state, nil, false)

    assert_equal JitSecurityJwtJwk::ALGORITHM, header.fetch("alg")
    assert_predicate result, :valid?
    assert_equal [jti, "/dashboard"], [result.jti, result.target_link_uri]
  end

  test "another client, a modified payload or signature, and non-PS256 headers are refused" do
    state, = OidcStateJwt.issue(client_id: CLIENT_ID, target_link_uri: "/dashboard")
    header, payload, signature = state.split(".")
    tampered_payload = Base64.urlsafe_encode64(
      JSON.generate(JSON.parse(Base64.urlsafe_decode64(payload)).merge("target_link_uri" => "/other")),
      padding: false,
    )

    bad_algorithm_tokens =
      %w(ES384 RS256 PS384).map do |algorithm|
        encoded_header = Base64.urlsafe_encode64(
          JSON.generate(JSON.parse(Base64.urlsafe_decode64(header)).merge("alg" => algorithm)), padding: false,
        )
        [encoded_header, payload, signature].join(".")
      end
    invalid_tokens = [
      OidcStateJwt.verify(client_id: "base-org-ww", token: state),
      OidcStateJwt.verify(client_id: CLIENT_ID, token: [header, tampered_payload, signature].join(".")),
      OidcStateJwt.verify(client_id: CLIENT_ID, token: "#{state[0..-3]}xx"),
      *bad_algorithm_tokens.map { |token| OidcStateJwt.verify(client_id: CLIENT_ID, token:) },
      OidcStateJwt.verify(client_id: CLIENT_ID, token: ""),
    ]

    assert invalid_tokens.none?(&:valid?)
  end

  test "the state expires immediately at its declared expiry" do
    issued_at = Time.current.change(usec: 0)
    state, = OidcStateJwt.issue(client_id: CLIENT_ID, target_link_uri: nil, now: issued_at)

    { 1799 => true, 1800 => false, 1801 => false }.each do |seconds, valid|
      travel_to(issued_at + seconds) do
        assert_equal valid, OidcStateJwt.verify(client_id: CLIENT_ID, token: state).valid?, "#{seconds}s"
      end
    end
  end

  test "a future issued-at claim beyond clock leeway is refused" do
    state, = OidcStateJwt.issue(client_id: CLIENT_ID, target_link_uri: nil, now: 2.minutes.from_now)

    assert_not_predicate OidcStateJwt.verify(client_id: CLIENT_ID, token: state), :valid?
  end
end
