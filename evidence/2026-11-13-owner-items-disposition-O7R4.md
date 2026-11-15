# Owner item dispositions

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Branch: `feature`

The shared worktree contained 1,115 changed or untracked paths at inspection. The results below
describe that combined worktree. This item made no schema, migration, model, checker, Herb, CI,
production or shared-database changes. No commit or push was made.

## Current observations

- `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency` exited 1 with exactly one
  finding: `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`. No checker configuration
  was present or changed. The finding concerns the custom JSON-text uniqueness validator paired with
  a partial PostgreSQL expression unique index; database_consistency 3.1.2 does not match this
  validator/index shape. The existing PostgreSQL index and model validator remain the enforcement
  contract.
- A read-only catalog scan of the 16 configured test writers found 79 NOT VALID foreign keys and
  zero NOT VALID CHECK constraints. The per-writer FK-count multiset was
  `[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 5, 9, 63]`, matching the prior recorded distribution: 5,
  9, 1, 1 and 63. The scan did not inspect production or shared databases.
- The event-18 identity contract was already tightened in the current worktree: both JSON text
  identity components must be non-NULL, enforced by model validation and a validated PostgreSQL
  CHECK; the weaker key-presence CHECK was removed. The partial expression unique index remains.
  Empty strings and non-string JSON value semantics remain as previously selected. Historical
  production/shared row conformity and validation cost have not been inspected.
- `docs/backlog/2026-11-10-herb-migration.md` records Herb adoption as decided and queued until
  split cleanup is complete in all four repositories; it explicitly says the tool decision is not to
  be re-evaluated. The prior ERB Lint comparison found that rule-set parity and speed have not been
  established.

## Items left unchanged for owner

| Item                        | Current disposition                                                                                                                    | Owner options and risk                                                                                                                                                                                                                                                                                                                |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DatabaseConsistency finding | Keep the model validator and PostgreSQL expression index. Do not weaken the event identity or add an exclusion to satisfy the checker. | Accept and track the confirmed checker capability gap; or evaluate a checker release/implementation that understands custom JSON-text expression uniqueness. Changing the tuple or index to an ordinary approximation risks breaking exactly-once audit identity.                                                                     |
| 79 NOT VALID foreign keys   | Leave migration and schema sources unchanged; no automatic validation, data repair or deletion.                                        | Keep pending; or approve a staged migration after a read-only inventory and an environment-specific lock/load and recovery plan. Validation can fail on historical orphans and can impose scan/lock cost. Production/shared validity and timing are unknown.                                                                          |
| Chronicle event-18 identity | Preserve the implemented non-NULL text-extraction contract and audit rows. No further schema/model change in this item.                | Keep the contract; or have the audit owner explicitly decide empty-string and JSON value-type semantics before any future tightening. Tightening without historical inventory can make validation fail; inferring identity or deleting rows would damage audit history. Production/shared rows and validation cost remain unverified. |
| Herb adoption               | Preserve the accepted decision and queue it until split cleanup completes across all four repositories.                                | Honor the recorded sequence; an owner may amend the decision if repository conditions materially change. Adopting early risks an unverified gap in ERB Lint checks and rendering compatibility; delaying retains the existing toolchain and its known limitations. The current backlog says not to re-evaluate the decision.          |

No new owner decision was requested or made in this session. These are not approval to alter any of
the four items. Relevant current sources: `specs/governance-database-consistency/spec.md`,
`specs/governance-database-consistency/halt-audit-identity-gap.md`,
`specs/governance-database-consistency/remaining-foreign-key-validation.md`,
`docs/backlog/2026-11-10-herb-migration.md`, and
`evidence/2026-11-13-ci-static-checks-zero-X2F7.md`.

## Verification

- `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency`: exit 1, one KEEP finding as
  stated above.
- `bin/rails runner -e test /tmp/governance-test-fk-state.rb`: exit 0; read-only aggregate returned
  16 writers / 79 NOT VALID FKs / 0 NOT VALID CHECKs.
- The scan emitted only aggregate counts in this evidence; no connection values or credentials were
  recorded.
