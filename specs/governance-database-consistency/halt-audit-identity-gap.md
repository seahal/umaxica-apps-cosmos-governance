# Halt audit identity gap

Historical investigation status: no schema change had been approved or applied when this review was
written. The later implementation disposition below records the resolution.

The findings and candidate section below preserve the pre-implementation investigation.

The retained Chronicle database has a partial unique index for `SIGN_FLOW_HALTED` (`event_id = 18`)
over the text extracted from `context.transaction_public_id` and `context.halt_generation`. Its
validated CHECK requires those JSON keys to be present, but PostgreSQL's `?` also treats an array
containing each key string as satisfying the check. An object with a JSON null value likewise
passes. In either case an index expression can evaluate to SQL NULL, so the unique index does not
enforce one row for that missing identity. The historical D-134 decision describes an exactly-once
identity based on both values; its archived status means current authority and the post-split
ownership of this historical event require reconciliation before a contract change.

Model validation now matches the existing key-presence check. This is not a fix for the NULL
uniqueness gap. A read-only aggregate of the current test Chronicle database returned no rows for
this event; no production or shared data were inspected. Existing audit history must not be deleted,
replaced, or silently invented to make a new constraint validate.

## Candidate contract for review

For this event, require both `context ->> 'transaction_public_id'` and
`context ->> 'halt_generation'` to be non-NULL. This rejects JSON null and arrays while retaining
existing text-extraction equality for string and numeric values. It deliberately does not decide
whether an empty string, boolean, object or array nested as a value is a valid identifier. Those
value types and the current owner of this event need an explicit decision before final
implementation; non-NULL alone should not be presented as a complete domain contract.

A candidate reversible migration could add a separate CHECK with `validate: false`, followed by a
separate validation after a read-only inventory of each target environment. The initial CHECK would
immediately reject new invalid rows, while validation scans historical rows and fails rather than
changing them. The migration must name its exact scope, lock budget, deployment order and recovery
procedure, and preserve the old CHECK and unique index until their replacement is explicitly
reviewed. No validation may be executed against production or shared databases under the current
authorization. A deployment migration must satisfy the migration rule and receive any required
scoped risk and recovery approval.

Before implementation, add PostgreSQL bypass tests and model tests for the chosen types and
accepted/rejected values, duplicate NULL bypass, both other-event and valid-event behavior,
concurrency, migration up/down, an existing-invalid-row validation failure, and a clean rebuild.
Define how every existing nonconforming audit row is retained and reconciled without fabricating its
identity. Run the checker and affected audit tests afterward; do not suppress its expression-index
warning.

## Implementation disposition (2026-11-13)

The active Governance database-consistency work selected the candidate non-NULL contract for both
text-extracted identity components. It leaves the JSON value types and PostgreSQL `->>` equality
semantics unchanged. The model rejects a missing or JSON-null component, and the database enforces
the same invariant for writes that bypass validations.

The implementation adds the stricter CHECK as `NOT VALID`, validates it in a separate migration,
then removes the weaker key-presence CHECK. Historical rows are retained; validation fails if any
row violates the new invariant. The custom model validator and partial expression index remain, so
duplicate non-NULL event-18 identities are still rejected.

The Chronicle test database was rebuilt from empty using current migrations. Its normalized schema
dump matches the rebuilt database, and a PostgreSQL catalog query found zero unvalidated
constraints. Focused Chronicle tests passed 6 tests / 56 assertions; the full Rails suite passed
7,492 tests / 49,876 assertions. The published `database_consistency` 3.1.2 run still reports the
expression-index validator shape; it is not suppressed. Production and shared databases were not
accessed. Production validation cost and the presence of nonconforming historical rows remain
unverified and need separate operational planning.

The same migration slice validates the 19 existing Chronicle foreign keys emitted `NOT VALID` by
migration history. It preserves definitions and data; invalid historical references cause migration
failure. Down migration preserves validated constraints because PostgreSQL cannot unvalidate a
foreign key without dropping it.
