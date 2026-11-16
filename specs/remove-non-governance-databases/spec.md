# Remove persistence Governance does not own

Status: implementing

Authority: owner request on 2026-11-12, prioritized ahead of the ongoing database consistency work.
The owner subsequently authorized judgment on removing OP associations and reconciling retained
code without changing surviving database schemas.

## Scope

Remove OP APP/ORG, Publishing, empty Search and six foreign RP cells (Core APP/ORG, Warp APP/ORG,
Palm APP, Edit ORG), including replicas, schema sources and exclusively dependent implementation.
Preserve the sixteen named surviving connections and their schemas. Local Base APP/ORG and Tech
ORG RP identity resolution remains distinct from Access OP state.

Existing dirty work, including the interrupted consistency improvements, remains intact except
where this explicit removal necessarily deletes an owned artifact. No shared or production database
may be dropped. Existing documentation, ADRs, checklists and diagrams are inventoried for the owner,
not rewritten during this change. CI database lists may be reconciled as explicitly requested;
unrelated CI construction is not part of this change.

## Acceptance

- AC-1: Removed connections, record classes and their exclusive consumers are absent from runtime;
  every remaining textual reference has an intentional disposition.
- AC-2: Database and abstract-record inventories contain only surviving owners and their existing
  static invariant tests pass. Record if any such guard does not exist.
- AC-3: Development and test database preparation succeeds with the reduced topology; distinguish
  isolated verification from any existing environment operation.
- AC-4: Run the requested Ruby, ERB, Brakeman, Rails and JavaScript checks. Separate pre-existing,
  removal-caused, blocked and unverified outcomes without weakening surviving behavior assertions.
- AC-5: Retained OP-dependent entry points fail explicitly and observably before unsafe work;
  unavailable authority never becomes empty successful results, false authorization evidence or a
  substituted RP session identity. Pure OP implementation is deleted rather than stubbed.
- AC-6: Verify hashes of all surviving schema/migration files and existing ADR/docs files against
  the task baseline, and record scoped evidence plus the stale-document inventory.

## Execution

Inventory the current inheritance and caller graph, delete disjoint exclusive implementation,
reconcile shared boundaries and inventories, then verify boot, behavior and full requested gates.
Keep the earlier consistency objective open and resume it only after this change is complete.

The request names an undefined guidance token `genec`; no matching file exists. Apply the existing
routed Rails, migration, security, fail-fast and static-invariant rules instead of inventing it.
