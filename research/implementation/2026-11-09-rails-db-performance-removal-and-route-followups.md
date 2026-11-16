# RailsDb and RailsPerformance removal with route-test follow-up

## Scope

Follow the owner-approved repository work orders in `docs/backlog/2026-11-10-remove-rails-db.md` and `docs/backlog/2026-11-10-remove-rails-performance.md`, then classify the 23 new Governance route-separation failures from evidence M6H2 and inspect development reference rows. No commit, external change, database reset, or volume deletion was authorized. The owner's later instruction to finish the work was treated as approval to insert the exact 121 previously listed development reference rows.

## Changes

- Removed both gems, their route/engine configuration and retired RailsPerformance-only code. Retained both forbidden mount paths.
- Removed RailsPerformance-only assignments from the tracked dev-container environment template and removed its stale route expectation from the Rails edge ownership test.
- Deleted the Auth-only email delivery integration test because it directly depended on a route removed with the Auth surface.
- Kept Base App local-cell failures unchanged. Recorded the 13 deferred cases and the missing session, ownership and verification-bootstrap contracts in evidence.
- Preserved all pre-existing worktree changes and did not commit.

## Verification and decisions

See `evidence/2026-11-09-rails-db-performance-removal-and-route-followups-V8Q3.md` for the per-case comparison, test results, current blockers and exact reference-row list.

The initial RailsPerformance removal exposed one stale assertion in `AppRailsEdgeOwnershipContractTest`; updating its expected route draws removed the additional failure. The final suite has 22 new failures matching 22 remaining M6H2 cases and no new errors. The other 109 failures and 24 errors match the prior baseline.

The development reference audit found 121 missing fixed-ID state rows in 17 tables. After the follow-up authorization, direct PostgreSQL transactions inserted the exact migration/seed-owned IDs; all 121 were verified present by a new read-only query. The initial write attempt failed before commit, and the rows were confirmed still missing before retry. No unrelated seeds, schema migrations, resets or deletions ran. Earlier Rails development boots may have run the preference-reference initializer and added rows to nine preference tables; no pre-start counts were captured, so that delta is unknown. No rollback was attempted, and no more development Rails boots were run.

Two files remain unedited because the workspace mounted them read-only: `.github/workflows/ci.yml` and `.devcontainer/compose.yaml`. External Cloudflare/tunnel/Access changes and container recreation remain outside the performed work.
