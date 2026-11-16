# Explicit passkey backup observations

Status: implementing

The owner approved this concrete storage shape on 2026-11-12. The existing
[display-only metadata decision](../../adr/passkey-authenticator-metadata.md) remains authoritative:
these observations do not grant permissions, determine credential identity, or change security policy.

| Legacy optional wire Boolean | Stored eligibility | Stored observation |
| --- | --- | --- |
| absent or null | unknown | unknown |
| false | ineligible | not_backed_up |
| true | eligible | backed_up |

`client_passkeys` and `operator_passkeys` replace nullable `backup_eligible` and `backup_state` with
NOT NULL `backup_eligibility` and `backup_observation` string enums. PostgreSQL CHECK constraints
bound the values above. Both default to explicit `unknown`. The two observations remain independent.
The existing Boolean wire names are unchanged; the shared metadata boundary normalizes them once.
Malformed optional flag values become unknown, preserving registration availability without
fabricating an affirmative observation. Callers cannot inject the persisted enum names through metadata.

The migrations preserve all nine true/false/NULL combinations in both directions. They use Rails
column conversion with explicit CASE expressions, require an exclusive table lock, and rewrite the
affected table. They do not delete credentials or change identifiers, owners, keys, sign counters,
audit records, or lifecycle state. They are not authorized for production execution by this task.
Production requires a separately approved maintenance/lock and recovery plan; rollback maps unknown
to NULL and restores exact Boolean meanings.

Acceptance requires normalization partition tests, real PostgreSQL rejection of invalid/NULL values,
exact migration roundtrip preservation, related credential registration regressions, and final
unconfigured DatabaseConsistency evaluation. Whole-database reconstruction belongs to the parent change.
