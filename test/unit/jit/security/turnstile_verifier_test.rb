# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_turnstile_verifier"

module Jit
  module Security
    class TurnstileVerifierTest < ActiveSupport::TestCase
      def setup
        # All four stub slots, not just the two this file sets: the challenge slot wins over the
        # verifier slot inside the stub, so a value left behind by another test would answer these
        # assertions instead of the injected response.
        TurnstileVerifierStub.reset!
      end

      def teardown
        TurnstileVerifierStub.reset!
      end

      test "returns failure on missing token when validation active" do
        TurnstileVerifierStub.enabled = false

        result = JitSecurityTurnstileVerifier.verify(token: "", remote_ip: "127.0.0.1")

        assert_not result["success"]
        assert_equal "missing cf-turnstile-response", result["error"]
      end

      test "returns failure on missing secret when validation active" do
        TurnstileVerifierStub.enabled = false

        # Ensure credentials/env return nil for secret key
        JitSecurityTurnstileConfig.stub(:visible_secret_key, nil) do
          result = JitSecurityTurnstileVerifier.verify(token: "token", remote_ip: "127.0.0.1")

          assert_not result["success"]
          assert_equal "missing turnstile secret", result["error"]
        end
      end

      test "injected verifier returns the stubbed response" do
        TurnstileVerifierStub.response = { "success" => true, "mock" => true }
        result = Turnstile::VerifierFactory.current.verify(token: "foo", remote_ip: "127.0.0.1")

        assert result["success"]
        assert result["mock"]
      end

      test "injected verifier reports success while the stub is enabled" do
        TurnstileVerifierStub.enabled = true
        result = Turnstile::VerifierFactory.current.verify(token: "foo", remote_ip: "127.0.0.1")

        assert result["success"]
      end

      test "injected verifier rejects an unstubbed provider call" do
        TurnstileVerifierStub.reset!

        assert_raises(TestSupport::ExternalCommunicationError) do
          Turnstile::VerifierFactory.current.verify(token: "foo", remote_ip: "127.0.0.1")
        end
      end

      test "performs http request when verifying" do
        TurnstileVerifierStub.enabled = false

        mock_response_body = '{"success": true}'

        stub_turnstile_response(mock_response_body) do
          result = JitSecurityTurnstileVerifier.verify(token: "valid", remote_ip: "1.2.3.4", secret_key: "secret")

          assert result["success"]
        end
      end

      # -- mode: :stealth -------------------------------------------------

      test "mode stealth uses JitSecurityTurnstileConfig stealth secret key" do
        TurnstileVerifierStub.enabled = false

        mock_response_body = '{"success": true}'

        JitSecurityTurnstileConfig.stub(:stealth_secret_key, "stealth-secret") do
          stub_turnstile_response(mock_response_body) do
            result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4", mode: :stealth)

            assert result["success"]
          end
        end
      end

      test "mode stealth returns failure without HTTP when secret is nil" do
        TurnstileVerifierStub.enabled = false

        http_called = false

        JitSecurityTurnstileConfig.stub(:stealth_secret_key, nil) do
          OutboundHttp::Connection.stub(:build, ->(**_kwargs) { http_called = true }) do
            result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4", mode: :stealth)

            assert_not result["success"]
            assert_equal "missing turnstile secret", result["error"]
          end
        end

        assert_not http_called, "HTTP should not be called when secret is nil"
      end

      test "mode visible uses JitSecurityTurnstileConfig visible secret key" do
        TurnstileVerifierStub.enabled = false

        mock_response_body = '{"success": true}'

        JitSecurityTurnstileConfig.stub(:visible_secret_key, "visible-secret") do
          stub_turnstile_response(mock_response_body) do
            result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4", mode: :visible)

            assert result["success"]
          end
        end
      end

      test "no mode falls back to visible secret key" do
        TurnstileVerifierStub.enabled = false

        mock_response_body = '{"success": true}'

        JitSecurityTurnstileConfig.stub(:visible_secret_key, "visible-secret") do
          stub_turnstile_response(mock_response_body) do
            result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4")

            assert result["success"]
          end
        end
      end

      test "explicit secret_key takes priority over mode" do
        TurnstileVerifierStub.enabled = false

        mock_response_body = '{"success": true}'

        config_called = false
        fake =
          -> {
            config_called = true
            "should-not-use"
          }
        JitSecurityTurnstileConfig.stub(:stealth_secret_key, fake) do
          stub_turnstile_response(mock_response_body) do
            result = JitSecurityTurnstileVerifier.verify(
              token: "tok", remote_ip: "1.2.3.4", secret_key: "explicit",
              mode: :stealth,
            )

            assert result["success"]
          end
        end

        assert_not config_called, "JitSecurityTurnstileConfig should not be called when secret_key is explicit"
      end

      test "logs sanitized response details in development" do
        TurnstileVerifierStub.enabled = false

        mock_response_body = {
          "success" => false,
          "error-codes" => ["timeout-or-duplicate"],
          "hostname" => "log.umaxica.app",
          "action" => "signup",
          "challenge_ts" => "2026-06-19T00:00:00Z",
          "cdata" => "opaque",
        }.to_json

        logger = Minitest::Mock.new
        logger.expect(:warn, nil) do |message|
          parsed = JSON.parse(message)

          assert_equal "turnstile.verify.response", parsed["event"]
          assert_equal "visible", parsed["data"]["mode"]
          assert_not parsed["data"]["success"]
          assert_equal "[FILTERED]", parsed["data"]["error_codes"]
          assert_equal "log.umaxica.app", parsed["data"]["hostname"]
          assert_equal "signup", parsed["data"]["action"]
          assert_equal "2026-06-19T00:00:00Z", parsed["data"]["turnstile_time"]
          assert parsed["data"]["cdata_present"]
          assert parsed["data"]["secret_key_present"]
          assert parsed["data"]["token_present"]
        end

        dev_env = ActiveSupport::StringInquirer.new("development")
        Rails.stub(:env, dev_env) do
          Rails.stub(:logger, logger) do
            JitSecurityTurnstileConfig.stub(:visible_secret_key, "visible-secret") do
              stub_turnstile_response(mock_response_body) do
                result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4")

                assert_not result["success"]
                assert_equal ["timeout-or-duplicate"], result["error-codes"]
              end
            end
          end
        end
        logger.verify
      end

      test "does not log response details outside development" do
        TurnstileVerifierStub.enabled = false

        mock_response_body = '{"success": true}'

        logger = Minitest::Mock.new

        Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
          Rails.stub(:logger, logger) do
            stub_turnstile_response(mock_response_body) do
              result = JitSecurityTurnstileVerifier.verify(
                token: "tok",
                remote_ip: "1.2.3.4",
                secret_key: "explicit",
              )

              assert result["success"]
            end
          end
        end
        logger.verify
      end

      test "verifying twice runs the real connection builder and never mutates the frozen siteverify URI" do
        # Regression: VERIFY_URI is a frozen class constant. OutboundHttp::Connection.build used to
        # hand it straight to Faraday, which mutates the URI's path, so every real Turnstile check
        # raised FrozenError and returned an "unavailable" failure (HTTP 422 on Google/Apple
        # sign-up confirmation). Exercise the real builder here and stub only the network POST.
        TurnstileVerifierStub.enabled = false
        uri_before = JitSecurityTurnstileVerifier::VERIFY_URI.dup
        fake_response = Struct.new(:body).new('{"success": true}')
        real_build = OutboundHttp::Connection.method(:build)

        OutboundHttp::Connection.stub(
          :build, lambda { |**kwargs|
                    connection = real_build.call(**kwargs)
                    connection.define_singleton_method(:post) { |*| fake_response }
                    connection
                  },
        ) do
          2.times do
            result = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4", secret_key: "secret")

            assert result["success"], "verification failed: #{result.inspect}"
            assert_nil result["error"]
          end
        end

        assert_predicate JitSecurityTurnstileVerifier::VERIFY_URI, :frozen?
        assert_equal uri_before.to_s, JitSecurityTurnstileVerifier::VERIFY_URI.to_s
      end

      private

      # siteverify is reached through OutboundHttp::Connection, so the stub
      # states the URL and the response body rather than mocking a transport
      # method. Verifying the stub keeps the "the request was actually made"
      # assertion the Minitest::Mock#verify calls used to provide.
      def stub_turnstile_response(body)
        stubs =
          Faraday::Adapter::Test::Stubs.new do |stub|
            stub.post(JitSecurityTurnstileVerifier::VERIFY_URI.to_s) { [200, {}, body] }
          end

        stub_outbound_http(stubs) { yield }

        stubs.verify_stubbed_calls
      end
    end
  end
end
