# frozen_string_literal: true

if ENV["COVERAGE"] == "true"
  # `require "simplecov"` already loads ./.simplecov, and that file loads the
  # "rails" profile along with the rest of the configuration. Passing the
  # profile to `start` as well would apply it a second time (only duplicating
  # filters, but splitting the configuration across two places). Keep .simplecov
  # as the single source of configuration and let `start` just begin tracking.
  require "simplecov"
  SimpleCov.start
end

ENV["RAILS_ENV"] ||= "test"
# Host names are deliberately NOT set here. This file is read after the application has
# already booted whenever the runner boots first (`bin/rails test` with no path argument,
# which is the documented command), and config/application.rb freezes
# Rails.configuration.x.boot_config from ENV at boot. An assignment made here therefore
# reaches ENV but never boot_config, leaving two disagreeing sources of truth for the same
# host and making results depend on how the suite was invoked. Host configuration belongs
# to the process environment (compose.yaml, the CI job env), which is set before boot.
# test/config/host_configuration_consistency_test.rb fails loudly if the two ever diverge.
ENV["SMTP_FROM_ADDRESS_APP"] = "from@umaxica.app"
RubyVM::YJIT.enable if defined?(RubyVM::YJIT)

require_relative "../config/environment"

# Build the test-mode Vite assets before anything renders a view.
#
# `config/vite.json` sets `"autoBuild": false` for test, and `/public/vite*` is gitignored, so
# nothing else in the repository guarantees that `public/vite-test` exists or is current. Every
# layout under `app/views/layouts` calls `vite_stylesheet_tag`/`vite_typescript_tag`, and
# `ViteRuby::Manifest#lookup!` raises from inside view rendering when an entry is absent, so a
# fresh checkout, a CI runner, or a run made after editing `src/` failed with an error naming an
# entrypoint instead of the missing build. Building here keeps that dependency explicit and
# satisfied in every environment.
#
# Placement matters: this runs in the parent process, before
# `ActiveSupport::TestCase.parallelize` forks workers, so one build serves the whole run instead
# of every worker racing to write the same output directory. `ViteRuby::Builder#build` compares a
# digest of the watched files against `tmp/cache/vite/last-build-test.json` and skips the Vite
# call when nothing changed, so a repeat run pays only for the digest.
unless ViteRuby.commands.build
  abort <<~MESSAGE
    Vite test-mode build failed, so public/vite-test has no usable manifest and every test that
    renders a layout would fail on a missing entrypoint. See the Vite output above; the same build
    runs standalone as `bunx vite build --mode test`.
  MESSAGE
end

require "rails/test_help"
# `Minitest.load(:test_prof)` only requires the Minitest reporter shims
# (`lib/minitest/test_prof_plugin.rb`); it does not load the TestProf recipe classes
# (`TestProf::EventProf`, `TestProf::StackProf`, `TestProf::MinitestSample`, ...), which live
# behind the gem's top-level `require "test_prof"` entrypoint. Loading them here only defines
# classes and registers `TestProf.activate` hooks that stay inert unless their env var
# (`EVENT_PROF`, `TEST_STACK_PROF`, `SAMPLE`, ...) is set, so this carries no cost for an
# ordinary `bin/rails test` run.
require "test_prof"
Minitest.load(:test_prof)
# `MinitestSample` (backs `SAMPLE`/`SAMPLE_GROUPS`) is a recipe, not part of the top-level
# `test_prof` require above, and must be loaded explicitly like any other TestProf recipe.
require "test_prof/recipes/minitest/sample"
require_relative "support/parallel_test_database_cloner"
require_relative "support/external_identity_test_helper"
require_relative "support/security_mode_test_default"
require_relative "support/operator_passkey_test_support"
require_relative "support/form_action_policy_helper"
require_relative "support/fetch_metadata_defaults"
require_relative "support/turnstile_verifier_stub"
require_relative "support/outbound_http_guard"
require_relative "support/outbound_http_stub"
require_relative "support/in_process_owned_surface_transport"
require_relative "support/service_stubs"
require_relative "support/valkey_test_isolation"
require_relative "support/set_cookie_assertions"
require_relative "support/withheld_assertions"
require_relative "support/cookie_jar_helper"
require_relative "support/inertia_page_object"
require_relative "support/strict_loading_association_preloader"
require_relative "support/public_id_fixed_length_assertions"
require_relative "support/rp_cell_session_helper"

# Inject the Turnstile stub for the whole suite. Application code resolves the verifier
# through Turnstile::VerifierFactory, so no production class knows about the test suite.
Rails.application.config.x.turnstile.verifier = "TurnstileVerifierStub"

module AuthenticationHarness
  include RpCellSessionHelper

  TEST_BROWSER_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV.fetch("DEFAULT_URL_HOST", nil)
    headers = { "Client-Agent" => TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil, select_available_app_persona: true)
    session = browser_rp_session_for(user, client_id: "base-app-ww", host:, session_public_id:)
    api_token = base_api_token_for_session(session)
    if select_available_app_persona && !session.selected_actor_context?
      selection = BaseSelectorAuthority.prepare(surface: :app, principal: user, session:)
      if Array(selection[:accounts]).empty? && user.status_id == ClientStatus::ACTIVE &&
          user.login_allowed? && user.access_enabled?
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
        selection = BaseSelectorAuthority.prepare(surface: :app, principal: user, session:)
      end
      candidate = Array(selection[:accounts]).first
      if candidate
        BaseSelectorAuthority.select(
          surface: :app, principal: user, session:,
          params: {
            account_public_id: candidate.fetch(:public_id),
            organization_public_id: candidate.dig(:organization, :public_id),
            organization_unit_public_id: candidate.dig(:organization, :unit_public_id),
            avatar_public_id: candidate.dig(:avatar, :public_id),
          },
        )
      end
    end
    cookies =
      headers.fetch("Cookie", "").split("; ").reject do |pair|
        [OidcRpBrowserCredentialContract::ACCESS_COOKIE, OidcRpBrowserCredentialContract::SESSION_COOKIE,
         OidcRpBrowserCredentialContract::REFRESH_COOKIE, AuthenticationCookieName.access,].include?(pair.split(
           "=",
           2,
         ).first)
      end
    cookies << "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(session.public_id)}"
    cookie_header = cookies.join("; ")
    result = host_headers(host).merge(headers).merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    result["Authorization"] = "Bearer #{api_token}" if api_token
    result
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil, select_available_org_persona: false)
    session = browser_rp_session_for(staff, client_id: "base-org-ww", host:, session_public_id:)
    api_token = base_api_token_for_session(session)
    if select_available_org_persona && !session.selected_actor_context?
      selection = BaseSelectorAuthority.prepare(surface: :org, principal: staff, session:)
      if Array(selection[:accounts]).empty? && staff.status_id == OperatorStatus::ACTIVE &&
          staff.login_allowed? && staff.access_enabled?
        BaseSelectorBootstrapAuthority.call(surface: :org, principal: staff)
        selection = BaseSelectorAuthority.prepare(surface: :org, principal: staff, session:)
      end
      candidate = Array(selection[:accounts]).first
      if candidate
        BaseSelectorAuthority.select(
          surface: :org, principal: staff, session:,
          params: {
            account_public_id: candidate.fetch(:public_id),
            organization_public_id: candidate.dig(:organization, :public_id),
            organization_unit_public_id: candidate.dig(:organization, :unit_public_id),
            avatar_public_id: candidate.dig(:avatar, :public_id),
          },
        )
      end
    end
    cookies =
      headers.fetch("Cookie", "").split("; ").reject do |pair|
        [OidcRpBrowserCredentialContract::ACCESS_COOKIE, OidcRpBrowserCredentialContract::SESSION_COOKIE,
         OidcRpBrowserCredentialContract::REFRESH_COOKIE, AuthenticationCookieName.access,].include?(pair.split(
           "=",
           2,
         ).first)
      end
    cookies << "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(session.public_id)}"
    cookie_header = cookies.join("; ")
    result = host_headers(host).merge(headers).merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    result["Authorization"] = "Bearer #{api_token}" if api_token
    result
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def with_preference_realm_issuers
    %w(app com org).each { |realm| JitSecurityJwtRegistry.issuer("preference_#{realm}") }
    yield
  end

  def assert_no_preference_state_cookies
    set_cookie = response.headers["Set-Cookie"].to_s

    [PreferenceCookieName.anonymous_jwt, PreferenceCookieName.anonymous_experience,
     PreferenceCookieName.binding, PreferenceIoKeys::Cookies::LANGUAGE,].each do |name|
      assert_not_includes set_cookie, "#{name}=", name
    end
  end

  def submit_step_up_completion_if_present!(host: nil, headers: {})
    return unless respond_to?(:response) && response.media_type == "text/html"
    return unless response.body.include?("step-up-completion-form")

    form = response.parsed_body.at_css("form#step-up-completion-form")
    raise StandardError, "step-up completion form missing" unless form

    params = {}
    form.css("input").each do |input|
      name = input["name"]
      params[name] = input["value"] if name.present?
    end

    action = form["action"].to_s
    action_uri = URI.parse(action)
    completion_headers = headers.except("Host", :Host).merge(host_headers(action_uri.host.presence || host))
    post(action, params: params, headers: completion_headers)
  end

  private

  def base_api_token_for_session(session)
    BaseApiAuthorityTokenIssuer.issue(rp_session: session)
  rescue BaseApiAuthorityTokenIssuer::InactiveRpSession
    nil
  end

  def browser_rp_session_for(resource, client_id:, host:, session_public_id:)
    client = OidcClientRegistry.find!(client_id)
    valid_resource =
      (client.resource_type == "client" && resource.is_a?(Client)) ||
      (client.resource_type == "operator" && resource.is_a?(Operator))
    raise ArgumentError, "test resource does not match its RP cell" unless valid_resource

    host_value = host || (respond_to?(:request, true) ? request&.host : nil)
    normalized_host = URI.parse(host_value.to_s.include?("://") ? host_value.to_s : "https://#{host_value}").host
    raise AccessOpDataUnavailableError unless normalized_host == OidcIssuer.host_for_client(client)

    @authentication_harness_rp_sessions ||= {}
    cache_key = [client_id, resource.public_id, session_public_id]
    session = @authentication_harness_rp_sessions[cache_key] ||= seed_rp_browser_session(
      client:, actor: resource, sid: session_public_id || SecureRandom.uuid, absolute_expires_at: 1.hour.from_now,
    )
    @base_browser_rp_session_public_ids ||= {}
    @base_browser_rp_session_public_ids[cache_key] = session.public_id
    session
  end

  def contact_owner_for_test(contact)
    case contact
    when ClientEmail, ClientTelephone then Client.find(contact.user_id)
    else raise ArgumentError, "unsupported Contact class: #{contact.class.name}"
    end
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil, authentication_context: nil)
    raise AccessOpDataUnavailableError if session_id

    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      else raise ArgumentError, "unsupported test resource"
      end
    client_id =
      case [resource_type, resource.class]
      when ["client", Client] then "base-app-ww"
      when ["operator", Operator], ["staff", Operator] then "base-org-ww"
      else raise ArgumentError, "test resource does not match its realm"
      end
    client = OidcClientRegistry.find!(client_id)
    session = browser_rp_session_for(resource, client_id:, host:, session_public_id:)
    now = Time.current.to_i
    claims = {
      "iss" => rp_test_issuer_for(client),
      "sub" => OidcSubject.for(resource, resource_type: client.resource_type),
      "aud" => [client_id],
      "client_id" => client_id,
      "sid" => session.op_session_binding.sid,
      "jti" => SecureRandom.uuid,
      "scope" => "openid profile domain:#{client.resource_type}",
      "iat" => now,
      "nbf" => now,
      "exp" => now + 600,
      "authn_ctx" => authentication_context || AuthenticationContextValue::NORMAL_KEY,
    }
    claims["cnf"] = { "jkt" => dpop_jkt } if dpop_jkt
    access_token = JitSecurityJwtKeyring.encode(
      claims, typ: "at+jwt",
              issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
    )
    install_base_rp_jwks_client(client_id:, access_token:)
    access_token
  end

  def destroy_test_client_after_cross_database_cleanup!(client)
    dependent_associations =
      Client.reflect_on_all_associations.filter_map do |association|
        association.name if association.options[:dependent]
      end
    Client.preload(*dependent_associations).find(client.id).destroy!
  end
end

module ActiveSupport
  class TestCase
    include AuthenticationHarness
    include WithheldAssertions
    include CookieJarHelper
    include ExternalIdentityTestHelper
    include FormActionPolicyHelper
    include OutboundHttpStub
    include PublicIdFixedLengthAssertions

    # Physical cores, not logical processors (SMT/vCPUs): measured on a 16-core/32-thread host --
    # `PARALLEL_WORKERS=32` (one per logical thread) took 37s on a 3000-test subset versus 22-24s
    # at 8 or 16 workers, because that many forked Rails processes plus Postgres itself oversubscribe
    # the physical cores and thrash instead of parallelizing further. See
    # docs/guides/test-profiling.md.
    #
    # A coverage run uses the same workers as any other run. `.simplecov` sets
    # `merge_subprocesses true`, so SimpleCov hooks `Process._fork` and each worker records and
    # writes its own resultset for the parent to merge; before that setting existed the run had to
    # be pinned to a single worker or the forked workers' coverage was lost.
    parallel_workers = Integer(ENV.fetch("PARALLEL_WORKERS") { Concurrent.physical_processor_count.to_s }, 10)
    raise ArgumentError, "PARALLEL_WORKERS must be positive" unless parallel_workers.positive?

    # The concrete legacy organization model was renamed to OperatorOrganization while the
    # physical table and fixture filename remain `organizations`. Without this explicit mapping,
    # Rails infers the removed Organization constant and loads the fixture on the wrong connection.
    set_fixture_class organizations: OperatorOrganization
    fixtures :all
    ValkeyTestIsolation.install!
    ParallelTestDatabaseCloner.install!(workers: parallel_workers)
    parallelize(workers: parallel_workers, parallelize_databases: false)

    # Rate-limit uses KVS Valkey namespaced by run and worker. Reset any
    # with_rate_limit_counters swap, then delete this worker's keys so counters
    # do not leak into the next case. Application cache is MemoryStore.
    setup do
      Rails.configuration.x.rate_limit.fetch(:store).reset!
      Rails.cache.clear
      ValkeyTestIsolation.cleanup_worker_keys!
    end

    # Same reasoning for the per-FQDN availability kill switch: it fails closed, so every served
    # FQDN is on by default here and a test that wants a surface switched off disables it itself.
    setup do
      FqdnAvailabilityRegistry.flag_names.each { |feature| Flipper.enable(feature) }
    end

    # Root-login availability is fail-closed, so ordinary regression tests
    # begin with both Base entry flags enabled. Blocked-path tests flip one flag.

    # I18n.locale is thread-local and is set by controller `set_locale`
    # before_actions during integration/controller tests. Those tests share
    # worker processes with model tests, so a request that leaves I18n.locale
    # at, e.g., :en would make a later model test read English validation
    # messages where it expects the default locale. Reset to the default after
    # every test so locale never leaks across the shared process.
    teardown { I18n.locale = I18n.default_locale } # rubocop:disable Rails/I18nLocaleAssignment

    # ENV is process-global and shared by every test a worker runs. Many integration helpers
    # (load_jump_rt_env!) write JWT_<NAMESPACE>_* without restoring them, and the local keyset
    # installer rejects such values, so a later test failed depending on seed order. Snapshot
    # ENV before each test and restore it afterwards so no assignment outlives its test.
    setup { @env_snapshot_before_test = ENV.to_h }
    teardown { ENV.replace(@env_snapshot_before_test) if @env_snapshot_before_test }

    # Class-level form of `with_rate_limit_counters`: a test case whose whole
    # subject is rate limiting declares this once and every test in it runs
    # against a deterministic MemoryStore. The per-test `setup` in the base
    # class already reset the store, and installing a fresh MemoryStore here
    # keeps buckets independent between tests in the same file.
    def self.rate_limit_counters!
      setup do
        Rails.configuration.x.rate_limit.fetch(:store).backend =
          ActiveSupport::Cache::MemoryStore.new
      end
    end

    # Opt a rate-limit-focused test into a deterministic in-process MemoryStore.
    # The default test store is namespaced Valkey; MemoryStore is still used when
    # a case needs time-travelled windows without talking to KVS.
    #
    # MemoryStore honors expires_in against Time.current, so window resets are
    # asserted by travelling time rather than sleeping.
    def with_rate_limit_counters(store = ActiveSupport::Cache::MemoryStore.new, &)
      Rails.configuration.x.rate_limit.fetch(:store).with(store, &)
    end

    # Rails.cache is already MemoryStore in test. This helper still swaps a
    # fresh store for cache-behavior tests that need an empty isolated instance.
    def with_application_cache(store = ActiveSupport::Cache::MemoryStore.new)
      previous = Rails.cache
      Rails.cache = store
      yield store
    ensure
      Rails.cache = previous
    end
  end
end
