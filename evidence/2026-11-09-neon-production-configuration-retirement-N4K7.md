# Neon Production Database Configuration Retirement

- Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`.
- The worktree was already uncommitted; results include the current uncommitted changes. No commit was made.
- Authority: `adr/staging-aurora-postgresql-topology.md`, amended 2026-11-09.
- Removed production database entries and `NEON_*` reads from `config/database.yml`, along with the `production_value` lambda and production-only database names. The production mapping is empty. `config/application.rb` raises `Production database is not configured; select a database provider before booting.` during production boot.
- The `development` and `test` database blocks were unchanged; the removed connection fields were only used to generate production settings. The Neon-specific assertion was removed from `test/unit/database_password_config_test.rb`. No Minitest case was added for environment construction, in accordance with `adr/no-test-suite-for-environment-construction.md`.
- `git grep -iw neon -- config/ app/ lib/ test/`: zero matches. Separate `NEON_` and `production_value` scan over the same paths: zero matches.
- `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=test bin/rails test test/unit/database_password_config_test.rb`: 2 runs, 20 assertions, 0 failures, 0 errors, 0 skips.
- `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=development bin/rails runner 'puts Rails.env'`: exited 0 and booted development.
- `UMAXICA_ENV_FILE=/dev/null RAILS_ENV=production bin/rails runner 'puts Rails.env'`: exited 1 with the explicit missing-production-database message above.
- `bin/rubocop config test`: after correcting eight formatting offenses surfaced in the existing route-separation changes, 2,288 files inspected, no offenses.
- `git diff --check` on the affected configuration and test files passed.
- No `.env*`, `.devcontainer/`, or `compose*.yaml` file was opened or edited. No external service was contacted. No explicit database create, reset, or delete command was run; the requested test used the existing test database.
