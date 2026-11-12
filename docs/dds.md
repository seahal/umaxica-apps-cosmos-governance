# Detailed Design

This document records the current Rails route and controller design after the surface hard reset.
The [current surface matrix](architecture/content-surface-matrix.md) owns the host inventory.

## Routes and controllers

- Base app, Base org and Base com route to `Base::App`, `Base::Org` and `Base::Com` controller
  namespaces under their own host constraints.
- Tech org routes to `Tech::Org` under its own host constraint.
- Mission Control Jobs, Flipper, Blazer, PgHero, Swagger and Coverband use dedicated operator
  host constraints. Their engine or Rack access controls remain local to each tool.
- Unmatched hosts receive the explicit unknown-host response. Rails framework endpoints retain
  their framework-owned routes.

Auth, Visa, Core, Warp, Palm, Edit, Docs, News, Help, Info and Guid route/controller trees have been
removed. Auth/Visa URL configuration is gone, so Base and Tech OIDC sign-in, callbacks, logout,
and OIDC-driven step-up are unavailable. Base app and Base org retain local RP-cookie validation
and fail closed when a new login requires the unavailable provider.

## Data and dependencies

No model or migration is removed in this step. The hard-reset evidence lists the models still used
outside `app/models`, identifies model/test-only references, and classifies each configured
database for the next cleanup step.

## Verification

The route inventory comes from `bin/rails routes`. The change gates are `bin/rails zeitwerk:check`,
`bin/rubocop`, `bundle exec erb_lint --lint-all` and `bin/rails test`.
