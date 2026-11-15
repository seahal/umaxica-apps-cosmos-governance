# typed: false
# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "jit_log_event"
require "jit_security_jwt_jwk"
require "openssl"

module JitSecurityJwtLocalKeysetInstaller
  module_function

  DEFAULT_STORE_PATH = Rails.root.join("tmp/local_jwt_keysets.json")
  STORE_FORMAT = "governance-single-keyset-v1"

  def install!(store_path: DEFAULT_STORE_PATH)
    store = load_store(store_path)
    changed = false

    changed |= install_keyset_issuer!(store, prefix: "AUTH", kid: "#{Rails.env}-governance-ps256-a")

    write_store(store_path, store) if changed
    drop_private_keys_outside_rp_cell!
    true
  end

  # An RP cell process keeps only the repository keyset assigned by RuntimeRole. Other roles are
  # unchanged; no per-surface or per-client signing key is installed.
  def drop_private_keys_outside_rp_cell!
    return unless RuntimeRole::RP_ROLES.include?(RuntimeRole.current)

    allowed = RuntimeRole.rp_private_env_names
    ENV.keys.grep(/_PRIVATE_KEY(SET)?\z/).each { |name| ENV.delete(name) unless allowed.include?(name) }
  end

  def install_keyset_issuer!(store, prefix:, kid:)
    active_name = "#{prefix}_JWT_ACTIVE_KID"
    private_name = "#{prefix}_JWT_PRIVATE_KEYSET"
    public_name = "#{prefix}_JWT_PUBLIC_KEYSET"
    if complete_env?(active_name, private_name, public_name)
      env_values = {
        "active_kid" => ENV.fetch(active_name),
        "private_keyset" => ENV.fetch(private_name),
        "public_keyset" => ENV.fetch(public_name),
      }
      return false if store[prefix] == env_values

      store[prefix] = env_values
      return true
    end

    env_values =
      if store.key?(prefix)
        store.fetch(prefix)
      else
        warn_local_keyset_regenerated(issuer: "GOVERNANCE", kid: kid)
        keyset_issuer_env(kid)
      end
    store[prefix] = env_values

    ENV[active_name] = env_values.fetch("active_kid")
    ENV[private_name] = env_values.fetch("private_keyset")
    ENV[public_name] = env_values.fetch("public_keyset")
    true
  end

  def complete_env?(*names)
    names.all? { |name| ENV[name].present? }
  end

  # Freshly minted local signing keys mean any token issued before this
  # boot (still sitting in a browser cookie) will fail verification. In
  # dev/test that surfaces as "access token rejected after restart ->
  # cookie discarded -> new token issued". The store normally prevents it
  # by persisting keys across boots, so a regeneration almost always means
  # the store under tmp/ was cleared (rails tmp:clear, fresh clone, CI,
  # container rebuild). Warn loudly so the cause is obvious in the log.
  def warn_local_keyset_regenerated(issuer:, kid:)
    Rails.logger.warn(
      JitLogEvent.format(
        "jwt.local_keyset.regenerated",
        issuer: issuer,
        kid: kid,
        env: Rails.env,
        store_path: DEFAULT_STORE_PATH.to_s,
        impact: "tokens issued before this boot for this issuer will fail verification until reissued",
      ),
    )
  end

  def load_store(path)
    return {} unless File.exist?(path)

    parsed = JSON.parse(File.read(path))
    unless parsed.is_a?(Hash) && parsed["_algorithm"] == JitSecurityJwtJwk::ALGORITHM &&
        parsed["_format"] == STORE_FORMAT && parsed.keys.sort == %w(AUTH _algorithm _format) &&
        parsed["AUTH"].is_a?(Hash) && parsed.dig("AUTH", "active_kid").present? &&
        parsed.dig("AUTH", "private_keyset").present? && parsed.dig("AUTH", "public_keyset").present?
      Rails.logger.warn(
        JitLogEvent.format(
          "jwt.local_keyset_store.contract_changed",
          expected_algorithm: JitSecurityJwtJwk::ALGORITHM,
          expected_format: STORE_FORMAT,
          path: path.to_s,
          impact: "local keysets will be regenerated and old local tokens will fail verification",
        ),
      )
      return {}
    end

    parsed.except("_algorithm", "_format")
  rescue JSON::ParserError => e
    Rails.logger.warn(
      JitLogEvent.format(
        "jwt.local_keyset_store.malformed",
        error_class: e.class.name,
        path: path.to_s,
      ),
    )
    {}
  end

  def write_store(path, store)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(
      path,
      JSON.pretty_generate(
        { "_algorithm" => JitSecurityJwtJwk::ALGORITHM, "_format" => STORE_FORMAT }.merge(store),
      ),
      mode: "w",
      perm: 0o600,
    )
  end

  def keyset_issuer_env(kid)
    key = OpenSSL::PKey::RSA.generate(JitSecurityJwtJwk::MIN_RSA_MODULUS_BITS)
    {
      "active_kid" => kid,
      "private_keyset" => JSON.generate(kid => base64_der(key)),
      "public_keyset" => JSON.generate("keys" => [public_jwk(key, kid)]),
    }
  end

  def public_jwk(key, kid)
    JitSecurityJwtJwk.export_public(key, kid: kid).merge("state" => "active")
  end

  def base64_der(key)
    Base64.strict_encode64(key.private_to_der)
  end

  private_class_method :install_keyset_issuer!, :complete_env?, :warn_local_keyset_regenerated,
                       :load_store, :write_store, :keyset_issuer_env
end
