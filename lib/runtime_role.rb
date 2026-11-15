# frozen_string_literal: true

# The single trusted execution role of this process (docs/security/role-secret-isolation.md).
#
# A role decides which controllers this process serves and which private signing keys it requires.
# It is read once from the process environment at boot and is never derived from request input
# (Host, `ri`, token claims). An unknown role aborts boot.
#
# A role does not select credentials or a database login: every process reads the Rails-standard
# config/credentials/<env>.yml.enc and the same database.yml (user decision 2026-10-19,
# adr/runtime-secret-isolation-deferred.md).
module RuntimeRole
  # `shared` is the pre-R5 process that serves every surface. It is a bounded transitional role: it
  # exists only because the development container is intentionally not split (user decision
  # 2026-10-17) and every cell is still served by one listener. Exit condition: R5-WU19 cell activation, after which a
  # cell process must boot with its own `rp-*` role and never as `shared`.
  SHARED = "shared"

  # Each retained RP cell serves only its own local store and loads the repository's
  # one signing keyset through the explicit JWT registry boundary.
  RP_ROLES = %w(rp-base-app-ww rp-base-org-ww rp-tech-org-ww).freeze
  # Canonical domain authorities: their own stores and protocol secrets only.
  DOMAIN_ROLES = %w(domain-avatar domain-org).freeze

  ALL = ([SHARED] + RP_ROLES + DOMAIN_ROLES).freeze

  class UnknownRole < ArgumentError; end

  module_function

  # Required: a process without an explicit role must not boot (no silent default to `shared`).
  def current
    name = ENV.fetch("UMAXICA_RUNTIME_ROLE")
    raise UnknownRole, "unknown runtime role: #{name.inspect}" unless ALL.include?(name)

    name
  end

  def shared?(name = current)
    name == SHARED
  end

  # The cell store connection of an RP role, e.g. rp-base-app-ww -> rp_base_app.
  def cell_connection(name = current)
    raise UnknownRole, "#{name} is not an RP cell role" unless RP_ROLES.include?(name)

    name.delete_prefix("rp-").split("-").first(2).unshift("rp").join("_")
  end

  # The repository has one signing keyset for its first-party JWTs. Each RP process needs that
  # shared keyset to issue its own client assertions and Jump RTs through the JWT registry.
  def rp_private_env_names(name = current)
    raise UnknownRole, "#{name} is not an RP cell role" unless RP_ROLES.include?(name)

    ["AUTH_JWT_PRIVATE_KEYSET"].freeze
  end

  BROWSER_ADMISSION_STATES = %w(open closed).freeze
  # Controllers an RP cell serves while browser admission is closed: process health and revision.
  CLOSED_CELL_PATHS = %r{/(health|healths|revisions)\z}

  # The cell's trusted local deployment admission; required in every rp-* process, never derived
  # from a request. A new cell process starts closed until its exact manifest is enabled.
  def rp_browser_admission_open?
    state = ENV.fetch("UMAXICA_RP_BROWSER_ADMISSION")
    raise UnknownRole, "UMAXICA_RP_BROWSER_ADMISSION must be open or closed" unless
      BROWSER_ADMISSION_STATES.include?(state)

    state == "open"
  end

  class UnownedRoute < ArgumentError; end

  # Any role may serve these: process health, revision, crawler files, CSP reports, browser
  # preferences and the retained anonymous com roots/content pages. They read no credential or actor.
  ANY_ROLE = "*"

  # Governance serves public verification metadata through its local RP boundary.
  BASE_METADATA_PREFIXES = %w(well_known).freeze

  # Authenticated Base app and org controllers use their own RP session boundaries.
  BASE_RP_PREFIXES = %w(
    roots
    switchers accounts organizations avatars avatar_ownership_transfers dashboard_avatar_images groups
    group_avatar_memberships billing billings iam support audit settings system
    identity identities verification verifications secrets secret_issuances secret_presentations
    selectors welcomes actor_support api/v0/identity api/v0/membership
  ).freeze
  BASE_RP_PROTOCOL_PREFIXES = %w(sign sign_outs oidc).freeze

  BASE_ANY_PREFIXES = %w(
    health healths revisions robots sitemaps csp_violation_reports preference preferences
    api/v0/healths api/v0/revisions api/v0/preferences
  ).freeze

  # Owner APIs of the canonical domain authorities (R5-WU12/13/14).
  BASE_DOMAIN_PREFIXES = {
    "api/v0/avatar" => "domain-avatar",
    "api/v0/iam" => "domain-org",
    "api/v0/support" => "domain-org",
    "api/v0/tech_capability_checks" => "domain-org",
  }.freeze

  OPERATOR_TOOL_FAMILIES = %w(mission flipper blazer pghero swagger coverband).freeze

  # The single role allowed to serve a routed controller, or ANY_ROLE. An unclassified controller
  # raises: a new route must be assigned an owner explicitly, never inherit one by accident.
  def route_owner(controller_path)
    family, realm, rest = controller_path.to_s.split("/", 3)
    case family
    when "tech" then "rp-tech-org-ww"
    when "base" then base_route_owner(realm, rest.to_s)
    when "unknown_hosts", *OPERATOR_TOOL_FAMILIES then ANY_ROLE
    else raise UnownedRoute, "no runtime role owns #{controller_path.inspect}"
    end
  end

  def base_route_owner(realm, rest)
    return ANY_ROLE if realm == "com" && rest == "roots"

    matches = ->(prefix) { rest == prefix || rest.start_with?("#{prefix}/") }
    BASE_DOMAIN_PREFIXES.each { |prefix, role| return role if matches.call(prefix) }
    return ANY_ROLE if BASE_ANY_PREFIXES.any?(&matches)
    return "rp-base-#{realm}-ww" if BASE_METADATA_PREFIXES.any?(&matches)
    return "rp-base-#{realm}-ww" if %w(app org).include?(realm) && BASE_RP_PROTOCOL_PREFIXES.any?(&matches)
    return "rp-base-#{realm}-ww" if BASE_RP_PREFIXES.any?(&matches)

    raise UnownedRoute, "no runtime role owns base/#{realm}/#{rest}"
  end

  # True when this process may serve the controller; the shared transitional role serves all. An
  # RP cell whose browser admission is closed serves only CLOSED_CELL_PATHS.
  def serves?(controller_path, name = current)
    return true if shared?(name)

    owner = route_owner(controller_path)
    return false unless owner == ANY_ROLE || owner == name
    return true unless RP_ROLES.include?(name)

    rp_browser_admission_open? || CLOSED_CELL_PATHS.match?(controller_path)
  rescue UnownedRoute
    false
  end
end
