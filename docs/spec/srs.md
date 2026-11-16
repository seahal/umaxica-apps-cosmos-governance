# Surface Requirements

This document records the current Rails surface boundary. The repository serves Base app, Base org,
Base com, Tech org and repository-local operator tools. Auth, Visa, Core, Warp, Palm, Edit, Docs,
News, Help, Info and Guid surfaces are retired from this application.

## Current behavior

- Base app and Base org keep their product, identity, preference, organization, health and API
  routes. Each is an RP with a neutral sign entry, callback, local sign-out and Back-Channel Logout
  receiver in its own RP cell. They use Visa and Jump for external handoffs; the Visa Org
  authorization endpoint currently answers 503. No OIDC-driven step-up callback is served.
- Base com remains the anonymous public surface, including its intentionally retained `.com` routes
  and corporate host configuration.
- Tech org keeps its operator dashboard and health/API routes. OIDC sign-in, callback, RP-initiated
  sign-out, and Back-Channel Logout are unavailable.
- Mission Control Jobs, Flipper, Blazer, PgHero, Swagger and Coverband remain on their individual
  operator hosts and retain their tool-local access controls.
- Unknown hosts reach the explicit unknown-host response. They do not inherit another surface's
  routes or credentials.

## Data boundary

Models and migrations remain unchanged during this route/controller reset. The hard-reset evidence
records database classification and remaining non-model callers for the separately authorized
model/database cleanup step.

## Verification

Route ownership is checked with `bin/rails routes`. Rails loading, style, ERB and behavior are
checked with `bin/rails zeitwerk:check`, `bin/rubocop`, `bundle exec erb_lint --lint-all` and
`bin/rails test`.
