# typed: false
# frozen_string_literal: true

require "json"
require "uri"
require "jit_security_turnstile_config"

# TODO: AUDIT external access: calls Cloudflare Turnstile siteverify.
class JitSecurityTurnstileVerifier
  VERIFY_URI = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify").freeze
  # siteverify sits on the request path, and this call previously ran on the
  # stdlib default read timeout: an unreachable Cloudflare held the visitor's
  # request for a minute before the degraded-mode branch below was reached.
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  def self.verify(token:, remote_ip:, secret_key: nil, mode: nil)
    new(token: token, remote_ip: remote_ip, secret_key: secret_key, mode: mode).verify
  end

  def initialize(token:, remote_ip:, secret_key: nil, mode: nil)
    @token = token
    @remote_ip = remote_ip
    @mode = mode
    @secret_key = secret_key || resolve_secret_key
  end

  def verify
    return failure("missing cf-turnstile-response") if @token.blank?

    if @secret_key.blank?
      log_missing_secret
      return failure("missing turnstile secret")
    end

    response = perform_request
    log_development_response(response)
    response
  rescue StandardError => e
    # Decoupled notification: only if Rails event system exists
    if defined?(Rails) && Rails.respond_to?(:event)
      Rails.logger.info(
        JitLogEvent.format(
          "turnstile.verify.failed", error_class: e.class.name,
                                     error_message: e.message,
        ),
      )
    end
    failure(e.message, unavailable: true)
  end

  private

  def resolve_secret_key
    case @mode
    when :stealth
      JitSecurityTurnstileConfig.stealth_secret_key
    else
      JitSecurityTurnstileConfig.visible_secret_key
    end
  end

  def perform_request
    connection = OutboundHttp::Connection.build(
      url: VERIFY_URI,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
      require_https: true,
    )
    response = connection.post(
      VERIFY_URI,
      {
        "secret" => @secret_key,
        "response" => @token,
        "remoteip" => @remote_ip,
      },
    )
    JSON.parse(response.body)
  end

  def log_development_response(response)
    return unless defined?(Rails) && Rails.env.development? && defined?(Rails.logger) && Rails.logger
    return unless response.is_a?(Hash)

    Rails.logger.warn(
      JitLogEvent.format(
        "turnstile.verify.response",
        mode: @mode || :visible,
        success: response["success"],
        error_codes: response["error-codes"],
        hostname: response["hostname"],
        action: response["action"],
        turnstile_time: response["challenge_ts"],
        cdata_present: response["cdata"].present?,
        secret_key_present: @secret_key.present?,
        token_present: @token.present?,
      ),
    )
  end

  def log_missing_secret
    return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

    Rails.logger.warn("[Turnstile] Secret key is missing (mode=#{@mode || :visible}). Verification skipped.")
  end

  # `unavailable` marks a failure caused by Cloudflare being unreachable rather than by the
  # visitor failing the challenge. Only that kind of failure is eligible for the degraded
  # mode in TurnstileDegradation; a missing token or a missing secret never is.
  def failure(message, unavailable: false)
    { "success" => false, "error" => message, "unavailable" => unavailable }
  end
end
