# Governance identifier HMAC credentials

Status: implementing
Authority: owner request dated 2026-11-10 and
`docs/backlog/2026-11-10-secrets-from-credentials-only.md`.

The owner subsequently approved the proposed conditional privilege repair and four-scope
retained development digest recalculation. This authorizes the reviewed maintenance sequence,
not production, database reset/deletion, unrelated privilege expansion or commit.

## Scope and acceptance

Move only APP/ORG Email/Telephone live lookup HMAC keys to this repository's encrypted
development and test credentials. Preserve unrelated credentials and existing worktree changes.

- AC-1: Each environment contains four independently generated `SecureRandom.hex(32)` keys,
  distinct from each other and the previous local values. Values never enter output or records.
- AC-2: Remove the four definitions from `.env`, `.env.container.devcontainer` and both CI job
  environments. Lookup and history-key isolation read these four keys from encrypted credentials,
  without an ENV fallback or override.
- AC-3: Missing/blank credentials fail clearly even with ENV populated; realm/channel separation,
  history-key isolation and maintenance tests use the new source without fixed real key values.
- AC-4: Run affected tests, the security collection and scoped Ruby lint; record actual results.
- AC-5: Present the existing backfill command, constraints, risk and recovery plan. Execute no
  retained development DB rewrite before explicit owner approval. No DB deletion/reset or commit.
- AC-6: Verify a fresh development process boots and synthetic email lookup through the sign-in
  resolver has no configuration error. Recovery of existing-record lookup remains unverified
  until approved backfill completes.

## Implementation decisions and sequence

1. Inventory definition paths without values; generate all eight keys in memory and encrypt them.
2. Remove only the four ENV definitions; migrate consumers and affected test doubles.
3. Run narrow behavior checks, security checks and development read-only verification.
4. Record evidence and request the retained-data decision with concrete commands and limitations.

The installed Rails `Rails.app.creds` is `CombinedConfiguration` with ENV precedence, including
in development/test. Removing the application's explicit fallback alone does not satisfy AC-2.
These four keys therefore use `Rails.app.credentials.option` directly; changing the global creds
chain would expand this task to every application secret. Other secrets and non-secret environment
configuration remain outside scope. Production secret-store integration is separately owned.

Rotating live HMAC keys makes old lookup digests stale until recomputed. The ordinary
`IdentifierBlindIndexBackfill` service and the restricted `identifier_hmac:rotate` task have
different persistence permissions; do not bypass finalized-row guards to make the former work.
Partial maintenance completion must remain explicit, with writes frozen and recovery by retry
under the new keys. Never reset the DB, disable guards or restore exposed keys.

Verification evidence and acceptance disposition belong in the requested `evidence/` record.
The retained-data acceptance remains open while its approval or prerequisites are outstanding.

## Known environment blocker

The `.github` subtree is mounted read-only in this executor. Both CI job environments still
contain the four old definitions: their removal is part of AC-2 but cannot be applied here.
Do not claim CI source cleanup complete or bypass the mount restriction. Local `.env` and
`.env.container.devcontainer` cleanup is independently executable.

## Verification and pending acceptance

Results: `evidence/2026-11-10-identifier-hmac-credentials-H4K8.md`.
Focused checks passed (80 tests, 568 assertions); six-file RuboCop passed. The security collection
has three withdrawal HTTP 503 failures also reproduced with the two pre-change reader
implementations. Fresh and restarted development HTTP checks returned 200; synthetic read-only
APP sign-in and ORG email lookup passed without the four ENV names.

The initial preflight incorrectly reported invalid NOLOGIN ownership: it compared an ActiveRecord
PostgreSQL Boolean `false` with the string `"f"`. Corrected metadata checks validated all four
scoped roles, function owners, ACLs and guards; no repair migration or privilege change was needed.
The correction is recorded separately in
`evidence/2026-11-10-identifier-hmac-recalculation-R6C2.md`.

After owner approval, the existing restricted maintenance service recalculated APP Email (one
row) and ORG Email (one row); both Telephone scopes were empty. Source write locks and the paused
web/jobs supervisor protected the interval. Complete non-digest source comparison, committed
digest matching, two new atomic audit facts and existing-email/sign-in-resolver lookup passed.
Development services resumed and the existing server returned HTTP 200. AC-5 is complete and
AC-6 includes retained-email lookup verification. AC-2 CI cleanup and the unrelated AC-4 security
failures remain open; this spec is not verified or closed.
