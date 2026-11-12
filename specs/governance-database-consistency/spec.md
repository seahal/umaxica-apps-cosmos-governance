# Governance database consistency

Status: implementing

Authority: owner request on 2026-11-12, subsequently narrowed to Governance only.

Improve surviving PostgreSQL contracts without checker exclusions or weaker business invariants.
Preserve existing uncommitted split work. CI and Solid Queue are excluded. Production and shared
data are outside destructive reconstruction authorization.

## Acceptance

- AC-1: Classify every configured database before implementation; unresolved ownership remains pending.
- AC-2: Demonstrate meaningful changes with failing tests followed by passing PostgreSQL tests,
  relevant regressions and lint. Keep database enforcement independent of model validation.
- AC-3: Run unconfigured DatabaseConsistency and separate KEEP findings from other classifications.
- AC-4: Verify reconstruction and schema agreement for changed KEEP databases using isolated data.

## Initial classification

Reading replicas follow their writer's classification; separate test replica databases do not
imply separate ownership.

| Classification | Connections | Basis |
| --- | --- | --- |
| KEEP | primary | Current database configuration explicitly owns durable Flipper settings. |
| KEEP | app_zenith, org_zenith | Latest access-governance ownership backlog assigns accounts, credentials, organizations and roles to Governance. OP-specific tables still need individual disposition. |
| KEEP | avatar | Accepted cosmos-base-surface-decomposition ADR assigns canonical avatar/social data to Governance. |
| KEEP | rp_base_app, rp_base_org, rp_tech_org | The same decomposition decision assigns these RP surfaces to Governance. |
| TRANSFER | op_base_app, op_base_org | Latest ownership decision assigns OP state to Access; do not change source schemas. |
| PENDING | publishing | Press route transfer does not itself decide physical schema disposition. |
| PENDING | app_setting, org_setting, com_setting | Preference ownership direction does not settle physical consolidation. |
| PENDING | app_signal, org_signal, chronicle, occurrence, search | Post-split physical persistence disposition remains unresolved. |
| PENDING | storage | Explicitly reserved, not an active KEEP redesign target. |
| PENDING | rp_core_app, rp_core_org, rp_warp_app, rp_warp_org, rp_palm_app, rp_edit_org | Surface transfer alone does not settle physical database disposition. |
| EXCLUDED | queue | Owner explicitly excludes Solid Queue. |

Legacy principal migration directories belong to Zenith history, not separate configured databases.
Old publisher, principal, com_zenith and cache names are absent from current database configuration.
Solid Cache retirement does not authorize any Solid Queue change.

## Sequence and open verification

1. Capture the complete unconfigured checker baseline and map findings to owners.
2. Audit independent KEEP model groups, starting with concrete reproducible defects.
3. Define each contract and add tests before changing models or migrations.
4. Verify each unit, then reassess the complete KEEP scope.

Initial standard checker run exited 1 with findings. No zero-warning or reconstruction claim has
been established. Database access requires execution outside the restricted sandbox; primary
accepted connections there. Material acceptance remains open until recorded verification exists.

## 2026-11-12 approved schema units

- The owner approved replacing nullable passkey backup observations with two independent explicit
  string state axes; see [passkey metadata](passkey-backup-metadata.md).
- The owner approved validating all 42 existing unvalidated constraints found in migration-built
  KEEP databases: Avatar eight FKs, APP Zenith seventeen FKs and five CHECKs, ORG Zenith eleven FKs
  and one CHECK. Definitions and data remain intact. Invalid existing rows stop validation rather
  than being deleted. Rollback keeps validated constraints; production execution is not authorized.
- The owner approved RP Base APP/ORG source-history FK alignment: four CASCADE actions become
  RESTRICT, matching the existing Model refusal. Four redundant indexes are removed while the
  covering composite UNIQUE, partial UNIQUE and remaining delivery index stay intact. Recovery
  restores the original FK/index definitions; retained-row deletion is not part of this change.

Initial isolated reconstruction completed for all seven KEEP databases. After the 42-constraint
validation migrations, normalized schema dumps of current test databases and their independent
migration-built counterparts match for all seven. These observations precede later schema units;
final reconstruction and equality must be repeated for the finished worktree.

The fixed-ID completion-method catalog is application-owned. Durable ID-1 requires bigint even for
bounded catalogs; the initial inference that smallint was only a checker preference was incorrect.
The actual CHECK pins IDs to one through four, but does not supersede the accepted type contract.

Additional owner-approved units:

- Widen completion-method PK and referencing completion method FK from smallint to bigint,
  preserving the fixed IDs, rows and all constraints. Numeric down migration is bounded by the
  retained one-through-four CHECK and FK.
- Add five nonunique indexes for status/method reverse lookups and four additional nonunique
  source-actor indexes for ownership-transfer history. Existing partial/unique constraints stay.
- Require ClientProfile's Client, Member's Client and OperatorWorkspaceAccount's Department at the
  database boundary. The clarified owner decision makes all three FKs RESTRICT and Model parent
  relations restrict_with_error. This explicitly supersedes the initial mistaken description that
  Member-first automatic deletion was already the existing behavior: existing code used nullify.
  No automatic Member/Profile/Workspace deletion is introduced. Existing NULL data stops migration;
  no fabricated owner/backfill is authorized. Down restores original nullability and SET NULL FKs.

## Ownership amendment after non-Governance removal (2026-11-12)

The owner's explicit removal/retention inventory supersedes the initial pending classifications
above. Current KEEP writers are primary, storage (empty reservation), chronicle, app_zenith,
org_zenith, avatar, app_setting, org_setting, com_setting, app_signal, org_signal, occurrence,
rp_base_app, rp_base_org and rp_tech_org. Queue remains EXCLUDED. OP APP/ORG, Publishing, Search
and six foreign RP connections are retired from Governance configuration and code; their physical
storage was not dropped and no external transfer completion is claimed.

The removal phase independently rebuilt 15 retained schema-owning stores in disposable development
and test environments, retaining all existing schema sources. Its full-suite checkpoint has 7,647
tests, 50,778 assertions, 16 failures, zero errors/skips. Those failures comprise nine existing
original-task Red cases, five unrelated retained Preference/CSP contract disagreements, one role
placement assertion (subsequently corrected) and one removal fixture keyword mismatch (corrected).
The workflow inventory patch remains blocked by a read-only mount. Final verification remains open.

The expanded PostgreSQL metadata audit found 98 additional NOT VALID foreign keys in six now-
confirmed KEEP databases. The exact plan is prepared, not applied. Existing definitions, actions,
columns and data must remain unchanged; historical orphan rows stop validation without deletion.
Their monotonic rollback policy requires a scoped owner decision, independently of the earlier
42-constraint approval. No new schema unit is approved by this paragraph.

## Expression-index checker result

The final unconfigured `database_consistency` run exits 0 with no finding lines for the current
worktree. The prior `OperatorChronicle` expression-index finding is now represented by a real model
validator with PostgreSQL's matching JSON text semantics and recognized in both checker directions.
No checker exclusion or schema alteration was used. The generic checker fork patch and its 478
RSpec examples are recorded in
[`evidence/2026-11-12-database-consistency-baseline-D8K2.md`](../../evidence/2026-11-12-database-consistency-baseline-D8K2.md).

This result does not resolve the separately documented duplicate-NULL gap in the historical audit
identity contract, and it does not validate the 98 additional NOT VALID foreign keys. The 98-FK
validation remains pending scoped approval. Therefore this specification remains `implementing`;
the zero-finding checker result alone does not close AC-2 or AC-4.

## Latest verification after coverage and removal continuation

The unconfigured KEEP checker was rerun against the current worktree and exited **0** with no
finding output. The latest coverage-disabled full Minitest suite passed **7,657 tests / 51,376
assertions / 0 failures / 0 errors / 0 skips**. SimpleCov separately ran the same tests but exited
2 at **86.08% line, 57.16% branch and 77.03% method coverage**, below its unchanged 98% / 93% / 97%
gates. The latest Vitest coverage run passed **68 files / 696 tests** and the unchanged 99% gates at
100% statements, 99.7% branches, 100% functions and 100% lines. These results are recorded in the
coverage checkpoint evidence. They do not validate the remaining 98 foreign keys or close the
Chronicle JSON identity gap; this specification remains `implementing`.
