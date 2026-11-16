# Reduce Environment Variables (2026-11-10)

Owner: this repository. Status: goal recorded; not started.

> **Scope update (2026-11-10):** The owner-approved local-surface hard reset authorizes removal of
> environment variables that exist only for removed foreign local route hosts and the retired
> `rails_performance` surface. This does not authorize a general cleanup of unrelated variables;
> the broader inventory and any additional removals still require their own approval.

## Goal

Keep the number of environment variables as small as possible (owner, 2026-11-10). Every variable is
something to provision, document, rotate and keep consistent across environments; unused ones add
that cost for nothing.

## Rules

- **Remove unused variables.** A variable that no code reads (Ruby, JavaScript, Compose, CI) is
  deleted from every `.env*` template, Compose file, CI workflow, document and deployment manifest in
  the same change.
- **Feature switches may move to Flipper.** The application already uses the `flipper` gem. On/off
  behavior toggles (feature flags, gradual rollouts, kill switches) can live in Flipper instead of an
  environment variable, so they change at runtime without redeploying.
- **What stays in the environment:** secrets (for example `SECRET_KEY_BASE`, delivered from SSM
  Parameter Store, `adr/cosmos-secret-key-base-in-ssm-parameter-store.md`) and deployment identity
  that must be known before the application can reach Flipper's storage: hosts and public URLs,
  database and Valkey connections, and the runtime role. Flipper is not a secret store and must not
  decide security boundaries or which hosts are trusted.
- Required variables keep the repository rule: one-argument `ENV.fetch("NAME")`, no code-side
  defaults (`adr/env-fetch-without-default.md`).

## First step (for Codex, read-only)

Inventory every variable referenced in code, configuration, Compose, CI and `.env*` templates
(names only, never values). Classify each as used, unused, or a candidate for Flipper, and propose
the removals. No variable is removed before the owner approves the list.

The owner separately approved removing variables used by the retired `rails_performance` surface as
part of `docs/backlog/2026-11-10-remove-rails-performance.md`. The 2026-11-10 hard reset also
authorizes variables used only by removed foreign local route hosts; unrelated environment-variable
cleanup remains out of scope.
