# Governance database consistency resumption

Date: 2026-11-13  
Repository: `umaxica-apps-cosmos-governance`  
Branch: `feature`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`

The shared worktree had 1,071 changed or untracked paths before this record. It contains substantial
pre-existing work, including earlier Governance database remediation and the newly completed
follow-up work orders. No reset, stash, commit, push, production database operation, shared
development database operation, or CI edit was made during this resumption.

## Database disposition

The active Governance inventory in `specs/governance-database-consistency/spec.md` supersedes its
earlier pending classifications:

| Classification | Governance connection(s)                                                                                                                                                                                    | Current disposition                                                                                                                                                                                                                              |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| KEEP           | `primary`, `app_zenith`, `org_zenith`, `avatar`, `app_setting`, `org_setting`, `com_setting`, `app_signal`, `org_signal`, `chronicle`, `occurrence`, `rp_base_app`, `rp_base_org`, `rp_tech_org`, `storage` | Retained Governance writers. `storage` remains an empty reserved connection.                                                                                                                                                                     |
| TRANSFER       | `op_base_app`, `op_base_org`; `publishing`; `rp_core_app`, `rp_warp_app`, `rp_palm_app`, `rp_core_org`, `rp_warp_org`, `rp_edit_org`                                                                        | Removed from Governance ownership/configuration under the explicit removal decision. Access owns OP state, Press owns Publishing content, and the other RP cells belong to their services. Completion of external data transfers is not claimed. |
| RETIRE         | `search`                                                                                                                                                                                                    | Removed from Governance; no owner or application tables were identified. Physical database deletion is not claimed.                                                                                                                              |
| EXCLUDED       | `queue`                                                                                                                                                                                                     | Solid Queue remains completely outside remediation.                                                                                                                                                                                              |

The removed connections above are not configured Governance databases in the current inventory. This
classification does not conflate removal from Governance with physical database deletion or
completed transfer. No unresolved Governance writer is promoted to KEEP by inference.

## Completed database remediation carried forward

Prior implementation and verification are recorded in
[`2026-11-13-database-consistency-final-H6Q2.md`](2026-11-13-database-consistency-final-H6Q2.md),
the active specification, and the associated unit evidence. The approved changes include:

- Explicit `unknown` passkey backup states, with the legacy Boolean input mapping preserved.
- Validation of the approved 42 pre-existing FK/CHECK constraints in Avatar, APP Zenith, and ORG
  Zenith, without changing definitions or deleting rows.
- RP Base APP/ORG history-FK `RESTRICT` semantics and removal of four redundant indexes.
- Bigint completion-method catalog/reference identifiers; five status/method lookup indexes and four
  ownership-transfer source indexes.
- Required ClientProfile/Client and Member/Client ownership and OperatorWorkspaceAccount/Department
  relations, enforced with NOT NULL and RESTRICT.
- Projected-attribute presence behavior for the retained model contracts.
- Chronicle `SIGN_FLOW_HALTED` JSON identity checks and validation of its 19 existing FKs. The model
  validator and partial expression unique index remain authoritative for duplicate identity.

No new schema unit was implemented in this resumption. In particular, the separate proposal to
validate 98 additional FKs across APP Setting, ORG Setting, APP Signal, ORG Signal, Chronicle and
Occurrence remains unapproved. No production/shared execution is authorized or claimed.

## Current verification

| Command                                                                                                                                                                                               | Result                                                                                                                                                                                                                           |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `env -u COVERAGE RAILS_ENV=test bundle exec database_consistency`                                                                                                                                     | Exit 1, one finding: `OperatorChronicle.uniq_operator_chronicles_sign_flow_halted`. No `.database_consistency.yml`, exclusion, or checker disablement was added.                                                                 |
| Scoped Chronicle tests using the current Governance test-writer list: `bin/rails test test/models/operator_chronicle_sign_flow_halted_test.rb test/models/operator_chronicle_halt_uniqueness_test.rb` | **6 tests / 56 assertions / 0 failures / 0 errors / 0 skips.**                                                                                                                                                                   |
| `RAILS_ENV=test bin/rails db:verify_no_schema_drift`                                                                                                                                                  | Exit 1; reports `db/app_setting_structure.sql`, `db/chronicle_structure.sql`, `db/occurrence_structure.sql`, and `db/org_setting_structure.sql`. This matches the outstanding validation/dump state in the active specification. |
| Full Rails suite after the ceremony cleanup                                                                                                                                                           | **7,492 tests / 50,156 assertions / 0 failures / 0 errors / 0 skips**, recorded in `2026-11-13-remove-unreachable-ceremony-code-V9Q2.md`.                                                                                        |
| `git diff --check` and current repository-knowledge check                                                                                                                                             | Passed in the ceremony evidence checkpoint.                                                                                                                                                                                      |

The first focused test invocation was rejected before tests ran because the inherited
`POSTGRESQL_TEST_PREPARE_DATABASES` environment listed removed, unverified database names. It was
rerun successfully with the explicit current writer list from the ceremony evidence. That list
includes `test_queue_db` because the repository test harness includes it; this resumption made no
Queue-specific code/schema changes and did not drop or recreate test databases.

The installed and locked checker is `database_consistency` 3.1.2. Its `UniqueIndexChecker` only
matches validators whose kind is `:uniqueness` and whose attributes/scope match parsed index
columns. `OperatorChronicle` uses `jsonb_text_uniqueness` over the JSON text expressions in a
partial index, so the released checker does not model this valid contract. The test and schema
contract were retained; no normal index or weakened validator was substituted to silence the
finding. The upstream project describes uniqueness validation checks in its
[README](https://github.com/djezzzl/database_consistency), while the checked-in resolved source is
the version-pinned 3.1.2 implementation described above.

## Final state

- KEEP DatabaseConsistency findings: **1** (the expression-index capability gap above).
- Direct PostgreSQL identity tests: **6 passed**; full Rails tests: **7,492 passed** in the latest
  recorded suite run.
- Empty-database reconstruction: earlier approved-scope builds are recorded in H6Q2 and the active
  specification; **no new reconstruction was run in this resumption**.
- Schema dump agreement: **not complete** for four listed schema dumps.
- Remaining work: scoped decision for the 98 additional FK validations; resolve checker support for
  the valid JSON expression index without exclusions or schema weakening; investigate/repair four
  dump discrepancies within their approved KEEP scopes; separately plan any production migration.
- No commit or push was made.
