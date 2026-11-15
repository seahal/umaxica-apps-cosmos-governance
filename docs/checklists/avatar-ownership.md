# Avatar organization ownership acceptance

Authority: approved A00–A16 and D-1–D-11 strategic decisions. The existing
[ownership spec](../../specs/avatar-organization-ownership/spec.md) retains historical findings and
rejected options; its Binding-only Grants, residual idempotency gap and shared-DB cleanup proposals
are superseded by those approvals, not acceptance alternatives. The criteria below preserve the
approved decisions for an investigator without the chat. The
[trigger ADR](../../adr/database-trigger-usage-boundary.md) applies with only the narrow
D-3/D-4/D-10 exceptions; no new SQL/trigger permission is granted here. Follow the
[investigation procedure](integrated-stack.md#independent-investigation).

## AV-1 — Concrete organization authority and identities

> **Access dependency (2026-11-13):** Governance retains Avatar ownership records and their local
> integrity constraints. Authenticated APP/ORG transfer operations currently fail closed because
> Access-owned authority data is unavailable. The operation and route tests below verify refusal
> before writes; they do not establish successful transfer behavior. Do not restore local Auth
> ceremonies or add a fallback while the Access API is pending.

- Basis: A01/A05, D-1. Scope: app Enterprise and org Bureau; com remains free of Avatar
  dependencies.
- Given an Avatar and each of the four supported source/destination families, provision and transfer
  it through supported interfaces. It always has one organization owner, never an individual or
  fractional owner; Avatar/Persona/ClientPersona/Agent/Enterprise/Bureau identities remain the same.
- Owner persistence has concrete target families: no polymorphic association/STI/type+ID/exclusive
  arc. Shared Ruby interfaces do not become generic persistence. Cross-DB organization/subject
  references retain public identity; local period/Avatar FKs retain concrete DB integrity (ID-3).
- `AvatarProvisioning::Create` writes the concrete Enterprise or Bureau first period in the same
  Avatar transaction, using `Avatar.created_at` as its initial boundary. The legacy period remains
  for the staged reader transition; retained data and direct test factories are not silently treated
  as migrated concrete ownership.
- Check schema/associations/resolvers, app initial and org optional provisioning in
  `test/models/avatar_concrete_ownership_period_test.rb` and
  `test/services/avatar_provisioning/create_test.rb`. Current transfer refusal is covered by
  `test/operations/avatar_transfer_unavailability_test.rb` and the APP/ORG route tests in
  `test/integration/base_access_authority_api_unavailable_test.rb`. These refusal tests do not prove
  successful transfer behavior.

The public concrete-owner regression in `test/models/avatar_test.rb` follows an Avatar's current
Enterprise period to its actual organization, with no Persona/Agent Binding required. The primary
Avatar/Enterprise/period fixtures explicitly describe that ownership and one shared synthetic start
boundary. This reference establishes a testable valid state; it does not replace the required
commit-time rejection of ownerless creation or certify all creation writers. The deferred
`avatar_initial_concrete_owner_required` constraint trigger now rejects a direct Avatar-only INSERT
at COMMIT with SQLSTATE `23514`; the regression is exercised through an independent PostgreSQL
connection in `test/models/avatar_concrete_ownership_period_test.rb`. The trigger checks that the
same transaction has exactly one current concrete period whose first `valid_from` equals the
Avatar's `created_at`; it does not choose an owner or rewrite data. This closes the Avatar INSERT
boundary while the remaining writer/cutover and cross-isolation acceptance stays open.

## AV-2 — Uninterrupted immutable temporal chain

- Basis: A05, D-3/D-4. Given a new Avatar, creation and its first owner period commit together with
  a creation-consistent boundary. Across Enterprise and Bureau periods, finite immutable start and
  immutable Avatar/owner, strictly later end, `[from,to)` adjacency and final positive infinity
  yield exactly one owner at every valid point, with no gap/overlap.
- The local concrete period slice now enforces strict intervals, same-family non-overlap, cross-
  family overlap rejection, an uninterrupted chain, exactly one current period, and direct-SQL
  history protections in PostgreSQL through
  `db/avatars_migrate/20261010130000_create_concrete_avatar_ownership_periods.rb`, its validation
  migration, and the forward immutability repair migration. The concrete Enterprise and Bureau
  models are explicit, and `test/models/avatar_concrete_ownership_period_test.rb` exercises these
  paths against the disposable database. New app/org provisioning is covered by
  `test/services/avatar_provisioning/create_test.rb` and the transfer provisioning regression.
  Transfer registry integration and full four-direction concrete period transition behavior remain
  unestablished.
- Attempt missing owner, equal/reversed/nonfinite start, cross-family overlap/gap, duplicate current
  periods and closed-history update/delete/truncate through SQL: DB rejects invalid commit
  explicitly, leaving prior history unchanged. Do not invent historical timestamps or rely only on
  model validation, partial current uniqueness or per-table exclusions.
- Check actual constraints/deferred triggers and real COMMIT in a new disposable catalog (MIG-3).
  Period-row checks have local tests, but their firing scope is not universal Avatar creation
  protection. The deferred `avatar_initial_concrete_owner_required` trigger added by
  `db/avatars_migrate/20261011212119_enforce_avatar_initial_concrete_ownership.rb` now rejects a
  committed Avatar-only INSERT at the Avatar boundary with SQLSTATE `23514` and leaves no row. The
  regression is exercised through direct SQL and a real COMMIT in the disposable database. This
  closes the missing-owner creation subcondition. The same test file now also performs raw-SQL real
  commits for an accepted adjacent chain, a rejected gap and a rejected cross-family overlap, and
  leaves the original history unchanged after each rejected commit. AV-1/AV-2 acceptance remains
  incomplete for full transfer and cutover conditions described below. The accepted ownership
  contract is unchanged.
- Finite starts are independently enforced by validated CHECK constraints introduced through
  `db/avatars_migrate/20261011041046_add_finite_concrete_avatar_ownership_period_starts.rb` and
  `db/avatars_migrate/20261011041103_validate_finite_concrete_avatar_ownership_period_starts.rb`. A
  matching nonfinite Avatar creation timestamp must not bypass them. Check both concrete tables,
  bypass model validation, inspect SQLSTATE/constraint identity, and verify real COMMIT/refusal on
  independent connections. The existing concrete-period test contains the direct bulk-write
  regression cases. This additive CHECK work does not prove the missing-owner or MVCC invariants.

## AV-3 — Concurrency and trigger boundary

- Basis: A04/A13/A15, D-3/D-4/D-11. Given independent connections racing owner changes at READ
  COMMITTED, REPEATABLE READ and SERIALIZABLE as applicable, deterministic success/refusal/retry
  preserves AV-2; stale snapshots never authorize a second current owner. Deadlock/serialization
  failures corrupt no history.
- Each necessary trigger's function and attachment exist together, with documented invariant/events/
  lock mode/order/SQLSTATE and reverse cleanup order. A required integrity counter may change only
  for concurrency, not become owner authority. No audit/notification/business side effects, silent
  correction, recursion/lock-upgrade bug or trigger disabling. Existing trigger inventory includes
  actual objects.
- The registry request race is exercised with two independent Avatar-DB connections in
  `test/models/avatar_transfer_reservation_test.rb`, and the concrete-period test now exercises two
  independent backend PIDs at READ COMMITTED, REPEATABLE READ and SERIALIZABLE. The
  trigger/concrete-period selection passed `22 runs, 79 assertions, 0 failures, 0 errors`, and the
  affected transfer/inventory selection passed `30 runs, 165 assertions, 0 failures, 0 errors` on
  the run-owned disposable fleet. The recurring Rails gate then completed with
  `15060 runs, 127731 assertions, 1 failure, 0 errors`; the only failure was the unrelated Acme
  terminology inventory check described in the
  [P7 evidence](../../evidence/2026-10-12-avatar-p7-concurrency-7K4M.md). These results prove
  deterministic period refusal and history preservation for this P7 slice, not the complete
  ownership-acceptance race, transfer cutover or dump/restore acceptance. Start at the
  [concurrency tests](../../test/models/avatar_transfer_reservation_test.rb),
  [concrete-period tests](../../test/models/avatar_concrete_ownership_period_test.rb) and
  [trigger tests](../../test/models/enforcement_triggers_test.rb). Approximately twenty draft
  triggers is not a required count. The same run's no-delete database/role preflight also verified
  20 disposable databases and 12 scoped HMAC roles after receipt-verified cleanup of stale worker
  clones. Block runtime acceptance without isolation.

Current resume evidence reran the concrete-period, registry-concurrency and trigger-inventory
selection against the run-owned four-worker manifest:
`28 runs, 101 assertions, 0 failures, 0 errors, 0 skips`
(`evidence/2026-10-12-avatar-concurrency-current-Q2F6.md`). This updates only the isolated
concurrency subcondition; it does not establish final transfer consumer cutover, Group semantics,
writer quiescence or the P12b marker.

## AV-4 — Global registry and concrete transfer cardinality

- Basis: A08, D-7. Given concurrent requests across any of four concrete transfer families, one
  shared type-neutral registry reserves operation public identity/idempotency key and enforces one
  pending operation per Avatar. Every committed registry has exactly its required concrete detail;
  every detail belongs to one registry. Direct SQL or simultaneous inserts cannot create
  orphan/multiple details.
- Source/destination/actor facts stay in concrete detail models. No transfer_type+transfer_id,
  owner_type+owner_id or exclusive arc in the registry. A later lookup that discovers duplicate keys
  is not acceptable eventual consistency; no residual cross-table uniqueness gap.
- The additive registry/detail schema is implemented in
  `db/avatars_migrate/20261010150000_create_avatar_transfer_reservations.rb`. It uses one shared
  idempotency namespace, one pending reservation per Avatar, concrete detail FKs, and a deferred
  PostgreSQL cardinality trigger that requires exactly one detail of the operation's family at
  commit. `AvatarOwnershipTransfers::ReservationCreator` creates the registry and its concrete
  detail in one Avatar-DB transaction and returns the existing reservation only when the immutable
  request tuple matches. A changed payload is rejected.
- The forward migration
  `db/avatars_migrate/20261010180000_enforce_avatar_transfer_source_period_avatar.rb` adds a
  deferred database guard for the second cross-table invariant: every concrete detail's source
  ownership period must belong to the same Avatar as its registry reservation. The guard raises
  SQLSTATE `23514` and cannot be bypassed by direct SQL.
- `test/models/avatar_transfer_reservation_test.rb` covers direct-SQL cardinality, source-period
  Avatar mismatch, pending/key uniqueness, same-request replay, changed-input refusal, and two
  independent committed connections racing on one key. The exact trigger inventory is asserted by
  `test/models/enforcement_triggers_test.rb`. Governance transfer operations currently refuse when
  Access-owned authority data is unavailable;
  `test/operations/avatar_transfer_unavailability_test.rb` verifies refusal before state writes, and
  `test/integration/base_access_authority_api_unavailable_test.rb` verifies HTTP 503 on APP/ORG
  routes. No successful transfer operation, result replay, or public controller behavior is claimed
  in the current tree. The Avatar schema and its database-level invariants remain; end-to-end
  transfer acceptance remains unverified until the Access API is available.
- P12b now has an independently reviewable, bounded transition path:
  `AvatarOwnershipTransitionInventoryQuery` classifies legacy/concrete ownership rows without
  writing them, `AvatarConcreteOwnershipBackfillOperation` offers dry-run and idempotent bounded
  apply for only unambiguous rows, and `AvatarOwnershipCutoverOperation` establishes an explicit
  singleton marker only after inventory readiness and an explicit writer-quiescence assertion. The
  marker's `id bigint` is also the actual PostgreSQL primary key through
  `db/avatars_migrate/20261012130000_promote_avatar_ownership_cutover_key.rb`; the singleton check
  and immutable marker triggers remain unchanged. The reversible barrier migration
  `db/avatars_migrate/20261011220000_add_avatar_ownership_cutover_barrier.rb` plus its logged-table
  repair `20261011220500_make_avatar_ownership_cutover_logged.rb` rejects legacy period, transfer,
  and Group-period INSERT/UPDATE/DELETE/TRUNCATE after the marker, while allowing those writes
  before it. The staged `avatar_group_concrete_ownership_periods` table is the post-marker source;
  its bounded inventory/backfill is implemented by `AvatarGroupOwnershipTransitionInventoryQuery`
  and `AvatarGroupConcreteOwnershipBackfillOperation`. `AvatarGroupOwnershipPeriodSource` selects
  the legacy source before the verified marker and the concrete source after it, without a legacy
  fallback. Direct-SQL barrier and trigger-inventory tests pass against the owned disposable
  PostgreSQL fleet. The marker has not been established in a shared or production database, and this
  implementation does not claim that operational backfill, consumer quiescence, or final read
  cutover has occurred.

  Runtime Avatar ownership now has the matching `AvatarOwnershipPeriodSource`. Before the marker it
  preserves the legacy reader plus the concrete reconciliation copy; after the marker it resolves
  current owners and owner-scoped selectors from concrete Enterprise/Bureau periods only, without a
  legacy fallback. New provisioning writes the legacy and concrete pair before cutover and only the
  concrete period after cutover. This source and database contract is covered by
  `test/models/avatar_ownership_period_source_test.rb`. Transfer operations currently refuse until
  the Access authority API exists, as tested by
  `test/operations/avatar_transfer_unavailability_test.rb`; no successful transfer writer or app/org
  controller path is claimed. The marker has not been established in a shared or production
  database.

  The current consumer ledger also records post-marker authenticated HTTP updates for APP and ORG
  Avatars and create/reorder/detach for APP Group memberships. Those marker-dependent cases run
  inside rollback-scoped tests; they verify local source selection and controller behavior, not a
  persistent cutover or independent committed-history race. See
  [`A7Q4`](../../evidence/2026-10-14-avatar-ownership-consumer-ledger-A7Q4.md).

  A current P10a transfer/Grant matrix covering concrete period and transfer validation, registry
  cardinality and replay, concurrency, cutover barriers, app/org controllers, Grant issuance and
  Avatar authorization passed `130 runs, 600 assertions, 0 failures, 0 errors, 0 skips`; see
  [`Z4M6`](../../evidence/2026-10-12-avatar-p10a-transfer-grant-matrix-Z4M6.md). This remains
  focused evidence: it does not establish Group account semantics, writer quiescence, operational
  backfill, final P12b cutover or the complete O1-to-O2-to-O1/client-transition matrix.

## AV-5 — Stable-key API and recorded-result retry

- Basis: A09/A10, D-8. Given an authorized initiator with canonical lowercase 36-character RFC UUID
  v4/v7 key and immutable Avatar/kind/input tuple, repeated creation returns the same operation
  identity or recorded result. Change inputs or initiator with that key: refuse without disclosing
  another actor's result. Unsupported version, malformed/noncanonical keys fail the stated API
  boundary.
- Existing keyless callers remain on the explicit additive transition without a promised full retry
  guarantee; per-request random server keys are not client idempotency. Registry public IDs remain
  NanoID. Cancelled/expired operations never revive. Permission to read an original result does not
  authorize executing a new transfer.
- The stable-key contract remains accepted, but current transfer callers stop at the unavailable
  Access authority boundary before mutation.
  `test/operations/avatar_transfer_unavailability_test.rb` and
  `test/integration/base_access_authority_api_unavailable_test.rb` cover this refusal. The current
  tree has no successful public transfer-controller path, and it does not verify key-mismatch
  refusal or successful recorded-result replay. Earlier transfer evidence is historical and is not a
  current pass for those behaviors.
- After the Access API is available, verify public transport, all four concurrent families, key
  format boundaries and authorized/unauthorized replay. Do not add a local data fallback to make
  these paths pass.

## AV-6 — Transfer acceptance is one local transition

- Basis: A10/A15. Given a pending request within the preserved five-day lifetime, accept after
  locks: revalidate original operation, source generation, source authority and destination
  acceptance authority, then use one DB-derived instant to close/open periods, record result,
  complete transfer and apply Grant/Group consequences in one Avatar DB commit. All four directions
  work.
- Lost-response retry finds the same success; stale generation, revoked authority, cancel, expiry
  (before/at/after) or non-increasing clock leaves history unchanged. Lock order is consistent
  across Group/Avatar writers and acquired facts are revalidated; no claimed Zenith/Avatar
  atomicity.
- AV-6 remains an accepted target but has no current success-path implementation while Access-owned
  authority data is unavailable. `test/operations/avatar_transfer_unavailability_test.rb` verifies
  that missing authority refuses before ownership writes. Database reservation and trigger tests do
  not establish a successful transition, failure rollback or retry. Complete those checks only after
  the Access API contract is available; prior transfer-matrix evidence is historical.

## AV-7 — N:M Grants remain generation-bound

- Basis: A06, D-5. Given one Identity with multiple Personas, multiple Personas may be authorized
  for one Avatar and one Persona for several Avatars through explicit supported concrete Grants.
  Each Grant binds Avatar, concrete subject, issuing period/generation, capability,
  validity/revocation and required granting-authority/audit facts.
- After O1→O2→O1, historical O1 Grants remain ineffective; a fresh authorized Grant is required.
  Wrong subject/period/capability, expiry or revocation cannot grant use. Existing
  management/transfer authority is distinct. Exclusive Bindings retain their documented meaning
  rather than becoming Grants by an index drop. No polymorphic subject/owner or disguised
  owner-generation reference.
- The P10a additive slice now provides explicit concrete tables (`avatar_enterprise_persona_grants`
  and `avatar_bureau_agent_grants`), bounded capability and revocation constraints,
  `AvatarAccessGrants::IssueOperation`, and `AvatarAccessGrantResolver`. `AvatarPermissionResolver`
  consults a matching current-period Grant only when an Avatar is supplied; existing
  organization-management authority remains a separate membership decision. Grant issuance itself
  requires the concrete app `Client` or org `Operator` named by the request to hold the explicit
  `avatar.grant.manage` owner authority for the current collective; a foreign or non-owner actor is
  refused before a Grant row is inserted. The authority check is locked with the owner membership
  and the concrete ownership period is rechecked before insertion.
  `test/services/avatar_access_grants_test.rb`, `test/resolvers/avatar_permission_resolver_test.rb`,
  `test/policies/group_avatar_membership_policy_test.rb`, and
  `test/services/group_avatar_memberships_test.rb` cover the implemented public behavior; the
  revision-scoped execution record is
  [`evidence/2026-10-12-avatar-p10a-grant-authority-4R7N.md`](../../evidence/2026-10-12-avatar-p10a-grant-authority-4R7N.md).
- Check resolver/policy/provisioning public behavior, N:M positives and denial cases plus direct DB
  integrity. The legacy Binding meaning remains unchanged. The Request/Accept/Cancel transport still
  has to cut over to the registry and concrete period generations before the complete O1→O2→O1
  acceptance path can be claimed. Group membership attach, reorder, and detach now recheck the
  concrete Avatar Grant under the locked Avatar state while preserving existing organization-owner
  authority; the public service and policy coverage is in
  `test/services/group_avatar_memberships_test.rb` and
  `test/policies/group_avatar_membership_policy_test.rb`. Transfer registry cutover and full Group
  transition consequences remain required before Avatar cutover. P10a and this Grant integration are
  independently reviewable and are not blocked solely by the unresolved Group account semantics in
  AV-8. The current transfer/Grant matrix passed
  `130 runs, 600 assertions, 0 failures, 0 errors, 0 skips`; see
  [`Z4M6`](../../evidence/2026-10-12-avatar-p10a-transfer-grant-matrix-Z4M6.md). A subsequent
  public-operation regression exercised O1 → O2 → O1 through the concrete registry: the closed O1
  Grant was ineffective both when the stale period object was supplied and when the new O1 period
  was current, while a newly authorized Grant was required. The focused slice passed
  `33 runs, 172 assertions, 0 failures, 0 errors, 0 skips`, and the following Rails/Vitest Gate 2
  passed `15155 runs, 128324 assertions, 0 failures, 0 errors, 0 skips` and
  `99 files passed, 1140 tests passed`; see
  [`G5N2`](../../evidence/2026-10-12-avatar-p10a-generation-reuse-G5N2.md). This closes the
  stale-period Grant non-reactivation subcondition only. It does not close the complete
  O1-to-O2-to-O1/client-transition, failure-injection, writer-quiescence or P12b cutover criteria.

## AV-8 — Group account meaning is not assumed ownership

- Basis: A03/A06/A10, D-2/D-5. Given actual account/creator/workspace/owner consumers, change Avatar
  ownership: independently meaningful account context is preserved while incompatible Group access
  does not silently survive. Only proven identical facts may be derived from concrete owner.
- Transitional account_surface/account_public_id never authorize ownership independently. All
  readers and data must migrate before future removal; no automatic Phase G deletion or controller
  redesign. If existing evidence cannot settle domain semantics, mark this criterion BLOCKED with
  exact decision, not PASS, a guessed conversion or NOT_APPLICABLE.
- Check Group policies/resolvers/provisioning and
  [existing Group period tests](../../test/models/avatar_group_ownership_period_test.rb), then
  concrete Group and transfer consequence tests. In the current tree, transfer operations fail
  closed until Access-owned authority data is available. The refusal regression in
  `test/operations/avatar_transfer_unavailability_test.rb` asserts that no ownership or Group
  membership state is written; it does not establish the success-path membership consequence. This
  hold affects P10b/P12b, not independent Grants or identifier history. Current
  `GroupManagement::Create` and `AvatarGroupPolicy` compare/filter selected subject account
  separately from owning collective; the app Avatar controller resolves that account as
  `ClientPersona`. The owning specification records these concrete observations. Account identity
  must not be replaced by owner identity. The meaning decision is therefore settled for the current
  contract: account context remains distinct from concrete organization ownership. These
  observations do not establish data reconciliation, a concrete account relationship, migrated
  consumers, or the full four-direction cutover; those implementation and operational steps remain
  required for this criterion. The read-only transition inventory also classifies a legacy or
  concrete Group history with a missing owner, invalid interval, non-creation initial boundary,
  multiple open periods, or a gap as `conflict`/manual review. The bounded Group backfill refuses
  that candidate and never invents a boundary. This protects the pre-cutover migration boundary; it
  does not resolve the account meaning or establish the cutover marker. The revision-scoped result
  is recorded in
  [`evidence/2026-10-12-avatar-group-inventory-S7H2.md`](../../evidence/2026-10-12-avatar-group-inventory-S7H2.md).

## AV-9 — Observable retention deferral

- Basis: A07, D-6. Given an Avatar eligible for purge, run retention repeatedly: no Avatar or
  ownership history is physically deleted; one idempotent actionable/auditable deferral records
  Avatar/reason and observations without needless PII. It neither silently skips an obligation nor
  loops forever on an opaque FK error. Reuse existing deferral facilities if sufficient.
- Ownership during suspension/logical deletion remains valid. Unresolved attribute/handle/media
  deletion/anonymization policy is recorded separately; preserving history is not indefinite PII
  retention permission. Identifier dead history follows CONTACT-7/9 independently.
- Check [retention job tests](../../test/jobs/retention_purge_job_test.rb) and the focused
  [Avatar retention tests](../../test/jobs/avatar_retention_purge_test.rb). The implemented
  `avatar_purge_deferrals` table records an idempotent `(avatar_id, reason_code)` observation and
  increments it under a row lock; ownership history is never physically deleted by the purge job. An
  eligible Avatar without concrete ownership history also remains intact, with an explicit
  `retention_policy_pending` deferral; encrypted moniker history is preserved. The absence of
  ownership periods does not authorize deletion. Personal-data retention duration and final
  deletion/anonymization policy remain unresolved and are not inferred from this deferral mechanism.

## AV-10 — Explicit lifecycle catalog booleans

- Scope: creation of AvatarLifecycleState reference records under the
  [lifecycle authority ADR](../../adr/avatar-lifecycle-state-authority.md).
- Each capability, visibility, owner-restoration and terminal flag has an explicit true or false
  value. False persists as a valid value; nil and empty boolean inputs are rejected before model
  insertion. PostgreSQL NOT NULL independently rejects validation-disabled NULL writes.
- Current catalog values, lifecycle transition edges and projected existing-record behavior remain
  unchanged. Check [catalog model tests](../../test/models/avatar_lifecycle_state_test.rb),
  lifecycle transition tests and the Avatar authority lifecycle invariant.
