# Halt audit identity gap

Status: investigation; no schema change approved or applied.

The retained Chronicle database has a partial unique index for `SIGN_FLOW_HALTED` (`event_id = 18`) over the text extracted from `context.transaction_public_id` and `context.halt_generation`. Its validated CHECK requires those JSON keys to be present, but PostgreSQL's `?` also treats an array containing each key string as satisfying the check. An object with a JSON null value likewise passes. In either case an index expression can evaluate to SQL NULL, so the unique index does not enforce one row for that missing identity. The historical D-134 decision describes an exactly-once identity based on both values; its archived status means current authority and the post-split ownership of this historical event require reconciliation before a contract change.

Model validation now matches the existing key-presence check. This is not a fix for the NULL uniqueness gap. A read-only aggregate of the current test Chronicle database returned no rows for this event; no production or shared data were inspected. Existing audit history must not be deleted, replaced, or silently invented to make a new constraint validate.

## Candidate contract for review

For this event, require both `context ->> 'transaction_public_id'` and `context ->> 'halt_generation'` to be non-NULL. This rejects JSON null and arrays while retaining existing text-extraction equality for string and numeric values. It deliberately does not decide whether an empty string, boolean, object or array nested as a value is a valid identifier. Those value types and the current owner of this event need an explicit decision before final implementation; non-NULL alone should not be presented as a complete domain contract.

A candidate reversible migration could add a separate CHECK with `validate: false`, followed by a separate validation after a read-only inventory of each target environment. The initial CHECK would immediately reject new invalid rows, while validation scans historical rows and fails rather than changing them. The migration must name its exact scope, lock budget, deployment order and recovery procedure, and preserve the old CHECK and unique index until their replacement is explicitly reviewed. No validation may be executed against production or shared databases under the current authorization. A deployment migration must satisfy the migration rule and receive any required scoped risk and recovery approval.

Before implementation, add PostgreSQL bypass tests and model tests for the chosen types and accepted/rejected values, duplicate NULL bypass, both other-event and valid-event behavior, concurrency, migration up/down, an existing-invalid-row validation failure, and a clean rebuild. Define how every existing nonconforming audit row is retained and reconciled without fabricating its identity. Run the checker and affected audit tests afterward; do not suppress its expression-index warning.
