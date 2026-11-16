# Front-Channel ID Token RP Implementation Evidence

Date: 2026-11-14  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Worktree: 1,334 paths were modified or untracked at final inspection. This worktree already
contained extensive uncommitted work. No commit or push was made. All reported checks ran against
this uncommitted worktree; the repository-wide schema-dump and reconstruction checks are affected by
its existing dirty schema state.

## Delivered

- Base App (`base-app-ww`) and Base Org (`base-org-ww`) start `response_type=id_token` requests with
  nonce and browser-bound signed state, without PKCE. The shared callback validates state and
  response issuer before reading the token, verifies the accepted PS256 Visa claim profile including
  `sid`, consumes the `jti` once, commits the local session, and returns 303 with a clean URL,
  `Cache-Control: no-store`, and `Referrer-Policy: no-referrer`. Error handling and the callback
  logging path do not return or log the token. Expired RP sessions renew through Visa with
  `prompt=none`; `login_required` returns to the ordinary sign entry.
- The generated Base App callback URL measured 1,923 UTF-16 code units in the test, under Jump's
  2,048-unit limit. This uses a generated test token; a live Access response has not been measured.
- Governance Base APIs use short-lived, realm- and audience-bound PS256 authority derived from the
  active RP session. Receivers verify the Governance token and reload that session. The Base
  Membership, Avatar, and Org Admin clients use this authority. The Tech capability client also uses
  it for its server-to-server check; Tech browser sign-in was not changed.
- A Base RP session cookie reaching a process that is not configured for that RP cell now fails
  with 503. A public Preference integration test had exposed the prior behavior: that process
  returned success while treating the signed-in update as a guest write and left the actor-local
  preference unchanged. The new test asserts refusal and no write to either actor-local or anonymous
  preference data. A configured Base RP process is separately tested to save and read the actor's
  preference.
- Both Base RP databases now have one-time ID Token JTI storage and per-session authentication
  evidence with unique constraints, validation constraints, and the session foreign key. The
  obsolete `rp_callback_states` tables and models are removed. The table-drop migration's rollback
  recreates the old empty schema; it cannot restore rows.
- `OidcOpTokenClient` has no remaining production caller and was removed.
  `OidcOpAccessTokenVerifier` remains for the non-Base `rp_tech_org` request-authentication path.
  Sign-out was outside scope and is unchanged: `OidcOpRevocationClient` remains called by
  `OidcRpLogoutLauncher` only when a bound Refresh Token cookie is present. The new callback
  installs no Access or Refresh Token cookie.
- README, scoped claims and RP authority ADRs, controller lifecycle documentation, Base RP Mermaid
  diagrams and transition inventories, and the session checklist describe the implemented profile.
  Implementation decisions and rollout limitations are in
  [research/implementation/2026-11-14-front-channel-id-token-rp.md](../research/implementation/2026-11-14-front-channel-id-token-rp.md).

## TDD and Migrations

- Red: the new integration expectation for an unconfigured process was run before the guard; it
  received 200 instead of the required 503. It exposed the anonymous-write fallback.
- Green: after the guard, `test/integration/preference_read_symmetry_test.rb` passed (7 runs, 61
  assertions). The session-revocation, enforcement, and preference focused group passed (14 runs,
  143 assertions). The related controller, identity, API-authority, model, and static HTTP-client
  guard group passed (21 runs, 335 assertions).
- The dedicated test databases were rebuilt from their migrations using
  `RAILS_ENV=test bin/rails db:migrate:reset:rp_base_app` and
  `RAILS_ENV=test bin/rails db:migrate:reset:rp_base_org`. All 26 App and 30 Org migrations
  completed. Both callback-state migrations were also rolled back and reapplied successfully. These
  commands targeted the Base RP test databases only; no development, shared, or production database
  was changed.

## Verification

| Command                                                          | Result                                                                                                                                                                                                                                                                                                                                                                               |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `bin/rails test` after the test DB rebuild                       | 7,627 runs, 51,019 assertions, 2 failures, 0 errors, 0 skips. The only failures are the unchanged `DatabaseReconstructionAuthorityTest#test_committed_structure_dumps_contain_real_table_definitions` and `#test_primary_uses_the_conventional_db/structure.sql_dump_path`; both were also present in the earlier full run.                                                          |
| `bin/rubocop`                                                    | Pass; 2,881 files inspected, no offenses.                                                                                                                                                                                                                                                                                                                                            |
| `bundle exec erb_lint --lint-all`                                | Pass; 1,501 files, no ERB errors. Parser emitted its Ruby 3.3 compatibility notice.                                                                                                                                                                                                                                                                                                  |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | Pass; no warnings.                                                                                                                                                                                                                                                                                                                                                                   |
| `bin/rails zeitwerk:check`                                       | Pass; “All is good!”                                                                                                                                                                                                                                                                                                                                                                 |
| `bundle exec database_consistency`                               | Pass; exit 0. The “No configuration files were provided” line is informational: in database_consistency 3.1.2 a run without a configuration file enables every checker and database, and it exits 1 on any failing report or rescued error. Rechecked 2026-11-14 on the same worktree with the same result; see `evidence/2026-11-14-pending-registration-lifecycle-design-PRL4.md`. |
| `bun run check`                                                  | Fails at the existing format check for `gait/features/sign_out/sign_out_confirmation.test.tsx`. That file was already dirty and was not reformatted.                                                                                                                                                                                                                                 |
| `bin/rails db:verify_no_schema_drift` (development and test)     | Fails because 16 structure dumps are dirty in the uncommitted worktree. The two RP dumps reflect these migrations; the other dumps are outside this work order. No dumps were force-rewritten or committed.                                                                                                                                                                          |

The 16 dumps reported by the drift check are `db/app_setting_structure.sql`,
`db/app_signal_structure.sql`, `db/app_zenith_structure.sql`, `db/avatar_structure.sql`,
`db/chronicle_structure.sql`, `db/com_setting_structure.sql`, `db/occurrence_structure.sql`,
`db/org_setting_structure.sql`, `db/org_signal_structure.sql`, `db/org_zenith_structure.sql`,
`db/queue_structure.sql`, `db/rp_base_app_structure.sql`, `db/rp_base_org_structure.sql`,
`db/rp_tech_org_structure.sql`, `db/storage_structure.sql`, and `db/structure.sql`.

`config/credentials` was unchanged. `.github/workflows/ci.yml` was already modified in the incoming
worktree and was left untouched. No CI configuration was changed.

## External Readiness and Remaining Risks

- Access still needs to implement and deploy the approved first-party `id_token` response for the
  two Base clients. Jump's deployed trust configuration and a real browser round trip were not
  available in this repository. Until those owners complete their work, live sign-in cannot be
  accepted from this change alone.
- The URL-size check used generated test material, not a live Access response.
- Applying the callback-state drop migration to a deployed database will invalidate pending legacy
  Code/PKCE callbacks. Users must restart sign-in. Rolling the migration back restores only an empty
  table. No production database was migrated.
- Sign-out retains its existing optional Refresh Token revocation path as required by the work
  order; it was not migrated to a new logout contract here.
- `DatabaseReconstructionAuthorityTest`, the dirty schema dumps, the unrelated Bun format failure,
  and Access/Jump deployment acceptance remain unresolved.
