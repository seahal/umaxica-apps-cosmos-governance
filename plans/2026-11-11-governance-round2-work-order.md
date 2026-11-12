Task (umaxica-apps-cosmos-governance): repair the test baseline, then cleanup round 2. Destructive
removal is approved; no compatibility layer; no commit. Never print secrets or environment values.

## Governance's surfaces (the only correct list; read this first)

OWN, keep:
- base: app, org, and com (`www.umaxica.*`). The 61 Base com routes kept on 2026-11-11 stay
  unchanged in this task (owner has not decided to retire them).
- tech: org (`tech.umaxica.org`)
- operator tools: mission, flipper, blazer, pghero, coverband, swagger
- unknown-host 404 fallback

Foreign: auth, visa (Access); core, warp, palm (Sphere); edit, docs, news, help, info (Press); guid,
performance. Governance is a relying party and the source of truth for Identity data
(accounts, credentials, profiles, organizations, roles). It is NOT an OpenID Provider: it never
issues authorization codes or tokens, never runs sign-in, sign-up, one-time-code or social sign-in
ceremonies (those run in Access; adr/access-is-a-pure-openid-provider.md in Access). Base/Tech OIDC
sign-in is currently disconnected on purpose; reconnecting it is a later task.

The 2026-11-11 surface hard reset (evidence/2026-11-11-surface-hard-reset-V4N8.md) is the starting
point. Do not re-add anything it removed.

## Do not touch

config/credentials/*.yml.enc, .devcontainer/**, .env* values (variable names listed below may be
removed, never print values), docs/backlog/**, plans/**, evidence/** (except your new record),
adr/**, migrations. Do not drop tables or databases.

## Part A: repair the test baseline (first)

The suite is red before any change: clean HEAD had 356 failures and 1,732 errors; after the hard
reset 252 failures and 1,588 errors. Most errors are `ActiveRecord::InvalidForeignKey` (about
1,490), then `NameError` and `I18n::MissingTranslation`.
1. Classify the errors by cause with counts (fixtures referencing rows or tables of removed or
   foreign models, fixtures load order, missing constants of removed code, missing translations).
2. Fix the causes in tests and fixtures: remove fixtures and tests that exist only for removed or
   foreign surfaces and models, and repair references in the rest. Never weaken a database
   constraint, disable foreign-key checks, skip tests or add placeholder tests to get green.
3. Re-run bin/rails test and record the new baseline (failures and errors with identifiers).
   Report what remains red and why.

## Part B: cleanup round 2

1. OpenID Provider leftovers, per docs/backlog/2026-11-11-move-valkey-auth-state-to-postgresql.md
   (Governance's copy): delete `app/services/valkey/auth_state/authorization_code_store.rb`, the OTP
   verification failure budgets (`app/models/email_otp_verification_failure_budget.rb`,
   `app/models/telephone_otp_verification_failure_budget.rb`) and every caller only they need.
   For `opaque_admission_store.rb` and the Base step-up marker adapter: delete them if no
   remaining Governance flow uses them after the hard reset; otherwise report the callers.
2. Social sign-in (Google, Apple, Microsoft Entra ID): remove the OmniAuth providers and
   initializer parts, social routes and controllers (`app/controllers/base/**/social`,
   `omniauth` callbacks), views, tests, and the gems `omniauth`, `omniauth-apple`,
   `omniauth-google-oauth2`, `omniauth_openid_connect` and `omniauth-rails_csrf_protection` if
   nothing else needs them. The Google and Apple credential entries were already removed on
   2026-11-11.
3. Primary-only reads, per docs/backlog/2026-11-11-no-automatic-replica-reads.md: remove
   `database_selector`, `database_resolver` and `database_resolver_context` from
   `config/initializers/multi_db.rb`; list every remaining `connected_to(role: :reading)`.
4. REPORT ONLY, do not change: under `app/controllers/base/{app,org}` classify `oauth`, `oidc`,
   `sign`, `verification`, `secret_*`, `identity`, `preference*` and similar authentication-looking
   code as (a) relying-party code Governance needs to sign in through Access later, (b) identity
   data management Governance owns, or (c) ceremony or provider code that belongs to Access and
   should be removed. Give file lists and reasons.

## Checks

bin/rails zeitwerk:check, bin/rails routes, bin/rubocop, bundle exec erb_lint --lint-all,
bun run check, bin/rails test. Report test results against the Part A baseline, new failures
separately. Before finishing confirm: `config/routes/` contains base.rb, tech.rb and the operator
tool files only; `bin/rails routes` lists no auth, visa, core, warp, palm, edit, docs, news, help,
info, guid or performance host and no social callback route; `app/services/valkey/auth_state/`
contains no authorization code store.

## Report

Record in evidence/YYYY-MM-DD-governance-round2-XXXX.md (full `git rev-parse HEAD`; note that
uncommitted changes affected results): error classification and fixes, new test baseline, removed
paths summary, the Part B4 classification, remaining reading-role uses, check results. No commit.
