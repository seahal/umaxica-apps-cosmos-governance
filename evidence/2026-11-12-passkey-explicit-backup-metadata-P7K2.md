# Explicit passkey backup metadata verification

Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`.
Results include uncommitted task changes and pre-existing split work; this is not a clean-HEAD result.
Scope: Governance ClientPasskey in app_zenith and OperatorPasskey in org_zenith only.
Accepted shape and migration limits: `specs/governance-database-consistency/passkey-backup-metadata.md`.

## Observations

- Before migration, safe aggregates in existing test PostgreSQL: ClientPasskey zero rows;
  OperatorPasskey twelve rows, every pair NULL/NULL. No production-data claims.
- Metadata normalizer Red: six tests, one failure and five errors; Green: six tests, 28 assertions,
  zero failures/errors/skips. Wire Boolean fields now map to explicit independent string enums;
  missing, nil and malformed optional observations map to unknown, not false.
- Model/database Red before applying the conversion: two tests, one failure and one missing-column
  error. This establishes the intended columns/defaults/constraints did not exist.
- Scoped migrations `20261112113703` and `20261112113708` applied successfully using
  `RAILS_ENV=test bin/rails db:migrate:app_zenith` and `db:migrate:org_zenith`, after verifying
  configured databases `test_app_zenith_db` and `test_org_zenith_db` on the configured primary.
- Generation initially left empty migration shells in active paths. Repository `db:test:prepare`
  automatically recorded those shells during Red execution. The initial scoped migration command
  therefore did no work. Exactly those two empty receipts were removed in these disposable test
  databases after confirming enum columns were absent, and the completed migrations then applied.
  No unrelated receipt or business row was removed. Future units should generate after Red or
  keep incomplete shells outside active migration paths.
- A Rails runner used official per-database migration contexts inside rollback transactions on the
  two explicit test databases. For each table all nine true/false/NULL pairs were written to the old
  Boolean columns and checked after up conversion and down conversion; up/down/up preserved every
  pair. Synthetic credential inserts and schema transitions were rolled back together. Output
  confirmed nine combinations for each database. This is existing-schema roundtrip verification,
  not empty-database reconstruction or production migration approval.
- Related regression before extra integration assertions: 63 tests, 300 assertions, zero failures,
  errors or skips. Files: passkey_backup_metadata_test, authenticator_metadata_test,
  client_passkey_test, operator_passkey_test, passkey_registration_operation_test and
  identity_passkey_ceremony_final_committer_test.
- Additional two-surface registration partition coverage and a ceremony-consumer propagation
  assertion were added. The next run had 64 tests/313 assertions with one assertion failure: test
  injected metadata into the decoded result but its fake consumer supplied a separate payload.
  The test input now places metadata into the consumed result actually committed by production.
  The parent change must run the corrected final suite; this record does not claim that rerun passed.
- Scoped schema dumps generated via `RAILS_ENV=test bin/rails db:schema:dump:app_zenith` and
  `db:schema:dump:org_zenith`. Before generation both dump paths were clean against HEAD. Besides
  intended enum changes, generated diffs show pre-existing FK validation drift and database-specific
  HMAC function role suffix differences. No generated dump was hand-edited. Parent integration owns
  canonical reconstruction, normalization, final dumps and `db:verify_no_schema_drift`.

## Limits and recovery

No CI or Solid Queue configuration was changed. No production/shared database was modified.
The conversion rewrites its table under an exclusive lock and requires separate production planning.
Down conversion maps unknown back to NULL and reverses observed positive/negative values exactly.
Tests directly bypass model validation with `update_all` to check PostgreSQL NOT NULL and CHECK
rejection. Whole KEEP reconstruction, final checker counts, final aggregate regressions and coverage
remain parent verification responsibilities.

## Scoped migration lock acknowledgement

Following review, the original broad `safety_assured` wrappers were narrowed. These are
StrongMigrations lock-risk acknowledgements for the explicitly approved atomic table rewrite;
they do not disable DatabaseConsistency or skip PostgreSQL constraint validation.

- Up acknowledges only the two renames, Boolean-to-string CASE conversions and NOT NULL scans.
- Defaults and enum CHECK creation (`validate: false`) execute with normal StrongMigrations checks.
- A second narrow block validates only the two named enum CHECKs. StrongMigrations would otherwise
  reject validation under the exclusive lock already acquired by that same atomic rewrite.
  PostgreSQL still scans and validates both constraints. Splitting this operation would introduce
  an intermediate schema; the scoped acknowledgement preserves transactional conversion.
- Down acknowledges only reverse CASE conversions and renames; other reversals remain ordinary.

This source adjustment does not rerun automatically on an already-applied environment. The parent
change must verify the final migration bodies through roundtrip and clean reconstruction; the earlier
roundtrip observations above describe the original semantically equivalent broad-wrapper bodies.
No suppression configuration, environment override, excluded Model or disabled DatabaseConsistency
checker was introduced. Production execution remains outside this task's authorization.

The narrowed final migration bodies were subsequently exercised with
`RAILS_ENV=test bin/rails runner tmp/passkey_metadata_roundtrip.rb`. Both explicit test databases
again preserved every one of the nine Boolean/NULL combinations through up/down/up and rolled back
the synthetic row and schema transaction. Both enum CHECKs were actually validated by PostgreSQL
through the narrower lock acknowledgements. Whole KEEP empty reconstruction remains the parent's
separate verification scope.
