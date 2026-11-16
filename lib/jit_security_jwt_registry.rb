# typed: false
# frozen_string_literal: true

require "jwt"
require "jit_security_jwt_issuer_builder"
require "jit_security_jwt_key_source"
require "jit_security_jwt_jwk"
require_relative "../app/errors/jump_rt_configuration_error"
require_relative "../app/values/jump_rt_surface"

module JitSecurityJwtRegistry
  module_function

  ALGORITHM = JitSecurityJwtJwk::ALGORITHM
  REQUIRED_JWK_FIELDS = JitSecurityJwtJwk::REQUIRED_PUBLIC_FIELDS
  PRIVATE_JWK_FIELDS = JitSecurityJwtJwk::PRIVATE_FIELDS
  SURFACE_NAMESPACES = %w(BASE_APP BASE_ORG).freeze
  MAX_JUMP_PUBLISHED_JWKS_KEYS = 4
  MAX_JUMP_PUBLISHED_JWKS_BYTES = 65_536
  MAX_JUMP_KID_LENGTH = 128
  ACCESS_TOKEN_SURFACE_NAMESPACES = SURFACE_NAMESPACES.freeze
  OIDC_CLIENT_NAMESPACES = %w(BASE_RP_APP_WW BASE_RP_ORG_WW TECH_ORG_WW).freeze
  # Issuer metadata for surface records without Jump issuer capability. Jump issuer records take
  # JumpRtSurface's PUBLIC_* origin instead, so the record that holds a Jump signing key names the
  # same `iss` the RT carries, and an invalid origin fails at boot rather than at request time.
  SURFACE_ISSUER_ORIGINS = {
    "BASE_APP" => "https://www.umaxica.app",
    "BASE_ORG" => "https://www.umaxica.org",
  }.freeze
  PREFERENCE_REALM_ISSUERS = {
    "preference_app" => { issuer: "https://www.umaxica.app", audience: "app" },
    "preference_org" => { issuer: "https://www.umaxica.org", audience: "org" },
  }.freeze

  ConfigurationError = Class.new(StandardError)

  DEFAULT_KID = "default"
  AUTH_AUDIENCE_ENV_NAMES = %w(
    AUTH_JWT_CLIENT_AUDIENCES AUTH_JWT_OPERATOR_AUDIENCES
  ).freeze
  # kid substrings that mark non-production / throwaway signing material. Such a
  # kid must never appear outside local Rails environments: it means dev/test/
  # fixture keys (often ephemeral, auto-generated under tmp/ by the local keyset
  # installer) are being published as if they were deployable keys.
  RESERVED_ENV_KID_PATTERN =
    /\b(?:development|test|local|fixture|sample|example|dummy|staging)\b/i

  def configure!
    source = JitSecurityJwtKeySource.new
    records = build_issuers(source: source)
    validate!(records)
    # rubocop:disable ThreadSafety/ClassInstanceVariable
    @issuers = records
    # rubocop:enable ThreadSafety/ClassInstanceVariable
    records
  rescue ConfigurationError => e
    Rails.logger.fatal(
      "jwt.registry.configuration_invalid error_class=#{e.class.name} reason=#{e.message.inspect}",
    )
    raise
  end

  def reload!
    configure!
  end

  def issuer(id)
    issuers.fetch(id.to_s)
  rescue KeyError
    raise ConfigurationError, "unknown JWT issuer registry id: #{id.inspect}"
  end

  def surface(namespace)
    issuer("surface:#{normalize_namespace(namespace)}")
  end

  def oidc_client(namespace)
    issuer("oidc_client:#{normalize_oidc_client_namespace(namespace)}")
  end

  def auth = issuer("auth")

  def issuers
    # rubocop:disable ThreadSafety/ClassInstanceVariable
    @issuers ||= configure!
    # rubocop:enable ThreadSafety/ClassInstanceVariable
  end

  def private_key_for(id, kid = nil)
    record = issuer(id)
    key = record.keys.fetch((kid || record.current_kid).to_s, nil)
    key&.private_key
  end

  def public_key_for(id, kid)
    issuer(id).public_key_for(kid)
  end

  def jwks_for(id)
    issuer(id).jwks
  end

  def parse_header(token)
    _payload, header = JWT.decode(token, nil, false)
    header || {}
  rescue JWT::DecodeError
    {}
  end

  def normalize_namespace(namespace)
    value = namespace.to_s.upcase
    raise ConfigurationError,
          "unsupported JWT issuer namespace: #{namespace.inspect}" unless SURFACE_NAMESPACES.include?(value)

    value
  end

  def build_issuers(source:)
    records = {}
    auth_audiences = AUTH_AUDIENCE_ENV_NAMES.flat_map { |name| source.csv(name) }
    auth_audiences.uniq!
    records["auth"] = build_repository_issuer(
      source: source, id: "auth", issuer: source.fetch("AUTH_JWT_ISSUER", nil),
      audiences: auth_audiences.freeze,
    )
    records["preference_com"] = build_repository_issuer(
      source: source, id: "preference_com", issuer: source.value("PREFERENCE_COM_JWT_ISSUER"),
      audiences: [source.value("PREFERENCE_COM_JWT_AUDIENCE")].compact.freeze,
    )
    records.merge!(build_preference_realm_issuers(source))

    SURFACE_NAMESPACES.each do |namespace|
      records["surface:#{namespace}"] = build_surface_issuer(namespace, source: source)
    end
    OIDC_CLIENT_NAMESPACES.each do |namespace|
      records["oidc_client:#{namespace}"] = build_oidc_client_issuer(namespace, source: source)
    end

    records.freeze
  end

  def build_preference_realm_issuers(source)
    PREFERENCE_REALM_ISSUERS.to_h do |id, configuration|
      [
        id,
        build_repository_issuer(
          source: source, id: id, issuer: configuration.fetch(:issuer),
          audiences: [configuration.fetch(:audience)].freeze,
        ),
      ]
    end
  end

  def build_repository_issuer(source:, id:, issuer:, audiences:)
    private_keyset = source.value("AUTH_JWT_PRIVATE_KEYSET")
    raise ConfigurationError, "AUTH_JWT_PRIVATE_KEYSET is required" if private_keyset.blank?

    build_keyset_issuer(
      source: source,
      id: id,
      private_keyset_name: :AUTH_JWT_PRIVATE_KEYSET,
      public_keyset_name: :AUTH_JWT_PUBLIC_KEYSET,
      active_kid: source.value("AUTH_JWT_ACTIVE_KID"),
      issuer: issuer,
      audiences: audiences,
      revoked_kids: source.csv("AUTH_JWT_REVOKED_KIDS"),
    )
  rescue JitSecurityJwtIssuerBuilder::Error => e
    raise ConfigurationError, e.message
  end

  def build_keyset_issuer(source:, id:, private_keyset_name:, public_keyset_name:, active_kid:, issuer:,
                          audiences:, revoked_kids:)
    JitSecurityJwtIssuerBuilder.build_keyset_issuer(
      id: id,
      private_keyset: source.value(private_keyset_name),
      private_keyset_source: private_keyset_name,
      public_keyset: source.value(public_keyset_name),
      public_keyset_source: public_keyset_name,
      active_kid: active_kid,
      issuer: issuer,
      audiences: audiences,
      revoked_kids: revoked_kids,
    )
  rescue JitSecurityJwtIssuerBuilder::Error => e
    raise ConfigurationError, e.message
  end

  def build_surface_issuer(namespace, source:)
    build_repository_issuer(
      source: source,
      id: "surface:#{namespace}",
      issuer: surface_issuer_origin(namespace),
      audiences: [jump_gateway_audience].freeze,
    )
  end

  def build_oidc_client_issuer(namespace, source:)
    build_repository_issuer(
      source: source,
      id: "oidc_client:#{namespace}",
      issuer: "oidc_client:#{namespace.downcase}",
      audiences: ["oidc-token-endpoint"].freeze,
    )
  end

  def private_key_required?(_record) = true

  def jump_gateway_audience
    Rails.configuration.x.boot_config.fetch(:jump).audience
  end

  def validate!(records = issuers)
    records.each_value { |record| validate_record!(record) }
    validate_global_kid_uniqueness!(records)
    validate_shared_keyset!(records)
    validate_jump_issuer_records!(records)
    true
  end

  def validate_shared_keyset!(records)
    canonical = records.fetch("auth")
    canonical_keys = keyset_contract(canonical)
    records.each_value do |record|
      next if keyset_contract(record) == canonical_keys

      raise ConfigurationError, "#{record.id} does not use the repository JWT signing keyset"
    end
  end

  def keyset_contract(record)
    [
      record.current_kid,
      record.revoked_kids.to_a.sort,
      record.keys.sort.each_with_object([]) do |(kid, key), entries|
        entries << [kid, key.public_jwk, key.state, key.private_key&.public_to_der]
      end,
    ]
  end

  def validate_jump_issuer_records!(records)
    JumpRtSurface::ISSUER_NAMESPACES.each do |namespace|
      record = records.fetch("surface:#{namespace}")
      keys = record.jwks.fetch(:keys)
      unless (1..MAX_JUMP_PUBLISHED_JWKS_KEYS).cover?(keys.size)
        raise ConfigurationError,
              "surface:#{namespace} published Jump JWKS must contain 1..#{MAX_JUMP_PUBLISHED_JWKS_KEYS} keys"
      end

      kids = keys.map { |key| key.fetch("kid") }
      unless kids.uniq.size == kids.size
        raise ConfigurationError, "surface:#{namespace} published Jump JWKS contains duplicate kid values"
      end

      keys.each do |key|
        validate_jump_kid!(namespace, key.fetch("kid"))
        validate_public_jwk!(key, source: "surface:#{namespace}:#{key.fetch("kid")}")
      end

      bytes = JSON.generate(record.jwks).bytesize
      next if bytes <= MAX_JUMP_PUBLISHED_JWKS_BYTES

      raise ConfigurationError,
            "surface:#{namespace} published Jump JWKS exceeds #{MAX_JUMP_PUBLISHED_JWKS_BYTES} bytes"
    end
  end

  def validate_jump_kid!(namespace, kid)
    valid =
      kid.is_a?(String) && kid.present? &&
      kid.codepoints.none? { |codepoint| codepoint < 0x20 || (0x7f..0x9f).cover?(codepoint) } &&
      kid.encode(Encoding::UTF_16LE).bytesize / 2 <= MAX_JUMP_KID_LENGTH
    return if valid

    raise ConfigurationError,
          "surface:#{namespace} kid must be a safe string of at most #{MAX_JUMP_KID_LENGTH} UTF-16 units"
  rescue EncodingError
    raise ConfigurationError, "surface:#{namespace} kid contains invalid encoding"
  end

  def validate_record!(record)
    return if record.current_kid.blank? && record.keys.empty?

    validate_record_metadata!(record)
    validate_active_key!(record)
    validate_record_keys!(record)
  end

  def validate_record_metadata!(record)
    raise ConfigurationError, "#{record.id} issuer is missing" if record.issuer.blank?
    raise ConfigurationError, "#{record.id} audiences are missing" if record.audiences.blank?
    raise ConfigurationError, "#{record.id} active kid is missing" if record.current_kid.blank?
    if enforce_public_key_hygiene? && reserved_env_kid?(record.current_kid)
      raise ConfigurationError, "#{record.id} active kid must not contain reserved environment markers"
    end
    return unless insecure_default_kid?(record.current_kid)

    raise ConfigurationError, "#{record.id} active kid must not be #{DEFAULT_KID.inspect}"

  end

  def validate_active_key!(record)
    unless record.keys.key?(record.current_kid)
      raise ConfigurationError, "#{record.id} active key #{record.current_kid.inspect} is missing"
    end
    if record.revoked_kids.include?(record.current_kid)
      raise ConfigurationError, "#{record.id} active key #{record.current_kid.inspect} is revoked"
    end

    current = record.keys.fetch(record.current_kid)
    if current.private_key.nil? && private_key_required?(record)
      raise ConfigurationError, "#{record.id} active private key is missing"
    end
    return if record.jwks.fetch(:keys).any? { |jwk| jwk.fetch("kid") == record.current_kid }

    raise ConfigurationError, "#{record.id} active key #{record.current_kid.inspect} is missing from JWKS"

  end

  def validate_record_keys!(record)
    record.keys.each_value do |key|
      if enforce_public_key_hygiene? && reserved_env_kid?(key.kid)
        raise ConfigurationError, "#{record.id}:#{key.kid} must not contain reserved environment markers"
      end

      validate_public_jwk!(key.public_jwk, source: "#{record.id}:#{key.kid}")
      raise ConfigurationError, "#{record.id}:#{key.kid} has invalid key state #{key.state.inspect}" unless %w(
        active grace retired revoked
      ).include?(key.state)
    end
  end

  def validate_global_kid_uniqueness!(records = issuers)
    seen = {}
    records.each_value do |record|
      record.keys.each do |kid, key|
        previous = seen[kid]
        next unless previous
        next if previous.fetch(:jwk) == key.public_jwk
        next if insecure_default_kid_allowed?(kid)

        if previous.fetch(:record_id) != record.id
          raise ConfigurationError,
                "duplicate JWT kid #{kid.inspect} in #{previous.fetch(:record_id)} and #{record.id}"
        end
      end

      record.keys.each { |kid, key| seen[kid] ||= { record_id: record.id, jwk: key.public_jwk } }
    end
  end

  def validate_public_jwk!(jwk, source:)
    JitSecurityJwtJwk.validate_public!(jwk)
  rescue JitSecurityJwtJwk::Error => e
    raise ConfigurationError, "#{source} #{e.message}"
  end

  def export_public_jwk(key, kid:)
    JitSecurityJwtJwk.export_public(key, kid: kid)
  end

  def surface_issuer_origin(namespace)
    return SURFACE_ISSUER_ORIGINS.fetch(namespace) unless JumpRtSurface::ISSUER_NAMESPACES.include?(namespace)

    JumpRtSurface.issuer_origin(namespace)
  rescue JumpRtConfigurationError => e
    raise ConfigurationError, e.message
  end

  def normalize_oidc_client_namespace(namespace)
    value = namespace.to_s.upcase
    unless OIDC_CLIENT_NAMESPACES.include?(value)
      raise ConfigurationError,
            "unsupported OIDC client JWT namespace: #{namespace.inspect}"
    end

    value
  end

  def insecure_default_kid?(kid)
    kid.to_s == DEFAULT_KID && !insecure_default_kid_allowed?(kid)
  end

  def insecure_default_kid_allowed?(kid)
    kid.to_s == DEFAULT_KID && Rails.env.local? && ENV["JWT_ALLOW_INSECURE_DEFAULT_KID"] == "1"
  end

  # True when dev/test/fixture signing material must be rejected. Local
  # development and test are allowed to mint local keys; every non-local Rails
  # environment must provide deployable key identifiers.
  def enforce_public_key_hygiene?
    !Rails.env.local?
  end

  def reserved_env_kid?(kid)
    RESERVED_ENV_KID_PATTERN.match?(kid.to_s)
  end

  private_class_method :build_issuers, :build_oidc_client_issuer, :build_repository_issuer,
                       :jump_gateway_audience, :validate_record_metadata!, :validate_active_key!,
                       :private_key_required?,
                       :validate_record_keys!, :validate_global_kid_uniqueness!, :validate_public_jwk!,
                       :validate_shared_keyset!, :keyset_contract,
                       :validate_jump_issuer_records!, :validate_jump_kid!,
                       :surface_issuer_origin, :normalize_oidc_client_namespace, :insecure_default_kid?,
                       :insecure_default_kid_allowed?, :reserved_env_kid?
end
