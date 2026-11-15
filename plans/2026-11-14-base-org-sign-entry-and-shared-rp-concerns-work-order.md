Task (umaxica-apps-cosmos-governance only): give Base Org the same relying-party sign entry that
Base App received today, and make the shared RP code realm-neutral so both realms use one set of
concerns. No commit. Never print secrets, key material or environment values. Never edit
config/credentials/*.yml.enc. No push, no deploy, no Cloudflare change, no change outside this
repository.

Follows `plans/2026-11-14-base-app-sign-entry-restoration-work-order.md` and its evidence
`evidence/2026-11-14-base-app-sign-entry-restoration-BAS1.md`. The same rules apply here (boundary,
what is not restored, stop conditions, tests Red first). Only differences are written below. The
earlier Org implementation is in history: `git show eedf4f51e~1:<path>`.

## Decision

Owner, 2026-11-14: extend the App result to Org now. Shared parts live in concerns; realm
controllers only declare what differs.

## Observed on 2026-11-14

- Base App works end to end up to the OP: `POST https://www.umaxica.app/sign` answers 303 to Jump,
  Jump answers 302 to `https://visa.umaxica.app/oauth/authorize`. The browser stopped silently until
  `config/initializers/content_security_policy.rb` added the OP origin to `form-action` (browsers
  apply `form-action` to every redirect after a submission). That change is in the tree
  (`op_form_hosts`, App only).
- The restored concerns hard-code App: `OidcCallback` and `OidcSsoInitiator` name `"base-app-ww"`,
  realm `"app"`, surface `"base_app"` and `visa_service` directly;
  `Base::App::ApplicationController` compares `browser_rp_client_id == "base-app-ww"`;
  `SurfaceChrome::ACCOUNT_NAVIGATION_SURFACES` lists only `base app`.
- At `eedf4f51e~1` the Org controllers were already thin (entries, interruptions, callbacks,
  closures differ from App only by module name); the realm values lived in
  `Base::Org::ApplicationController` (`oidc_sign_host` from `PUBLIC_AUTH_STAFF_URL`,
  `oidc_visa_authority_host` from boot config `visa_staff`).
- The current tree has no `visa_staff` in `lib/config_values_host_family_values.rb` and no Visa Org
  origin in the CSP. `config/environments/development.rb` and `production.rb` at `eedf4f51e~1`
  listed `PUBLIC_VISA_STAFF_URL` / `PRIVATE_VISA_STAFF_URL`.
- Access registers `base-org-ww` (worldwide, resource type `operator`, key namespace
  `BASE_RP_ORG_WW`) on the Base Org origin with the same paths as App: `/oidc/callback`,
  `/verification/oidc/callback`, `/sign/out/completion?ri=<region>`, `/oidc/closures`. The Visa Org
  issuer is `https://visa.umaxica.org`. Jump already has the edges `base-org-ww` ↔ `visa-org-ww`.
  Access's Visa Org authorization endpoint still answers 503 (a separate Access order reopens it).

## Work

1. Make the shared RP concerns realm-neutral first, with App behaviour unchanged (all App tests from
   the earlier order stay green before Org starts). Each concern asks the including controller for
   what differs, through private hook methods with no default (a missing hook raises,
   `generic/fail-fast.mdc`): client ID, realm, resource type, log surface, OP origin and JWKS URI,
   default landing path, route helpers. Remove every literal `"base-app-ww"`, `"app"` and
   `visa_service` from concerns and shared values. Do not add a realm switch (`case realm`) inside a
   concern; the realm controller answers its own hooks. Follow `generic/rails-concerns.mdc` and
   `docs/architecture/method-visibility-and-concerns.md`.
2. Configuration: restore `visa_staff` in the host family values from history (the variable name
   `PUBLIC_VISA_STAFF_URL` existed before; report names only). Add the Visa Org origin to
   `form-action` next to the App OP origin. If the development environment does not provide the
   variable, report it as an owner item and stop Org runtime checks; continue the code and tests.
3. Org realm: routes in the Base Org block of `config/routes/base.rb` matching App (`/sign`,
   `/sign/interruption`, `/oidc/callback`, then Part B `/sign/out`, `/sign/out/completion`,
   `/oidc/closures`); thin controllers under `app/controllers/base/org/` that include the shared
   concerns; the hooks in `Base::Org::ApplicationController`; the header link via
   `ACCOUNT_NAVIGATION_SURFACES`. Org has no public sign-up: use the sign-in label if a locale key
   exists for it, otherwise keep the shared label and report it. The RP cell is `rp_base_org`
   (models and database entry still present).
4. Step-up, Tech Org and every ceremony stay out of scope, as in the App order.

## Tests

Run the App suites unchanged after step 1 (they are the refactor's safety net). For Org, mirror the
App tests rather than copying them: prefer one test body exercised for both realms where the
existing helpers allow it. Org-specific cases: `state` signed for `base-app-ww` refused by the Org
callback and the reverse; an ID token from `https://visa.umaxica.app` refused by Org and the
reverse; Org header link present signed out; an App RP cookie does not sign anyone in on Org.

## Checks and report

As in the App order. Evidence in
`evidence/YYYY-MM-DD-base-org-sign-entry-and-shared-rp-concerns-XXXX.md`: hook list per concern,
literals removed, App results before and after the refactor, Org results, owner items (variable
values, label), and confirmation that config/credentials files are unchanged.
