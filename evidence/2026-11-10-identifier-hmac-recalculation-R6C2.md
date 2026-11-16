# Governance development identifier HMAC recalculation

Date: 2026-11-10
Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`
Worktree: extensive pre-existing uncommitted changes plus the credentials migration described in
`evidence/2026-11-10-identifier-hmac-credentials-H4K8.md`; this is not a clean-HEAD verification.
Scope: Governance development APP/ORG Email/Telephone retained lookup digests only.

## Authorization and correction

The owner replied `yoidesuyo` to the request to validate/repair the maintenance boundary as needed
and then recalculate the four selected scopes. This continued the previously presented freeze,
preservation, audit and fix-forward recovery plan. No production/staging operation, database
reset/deletion, secret display, external-provider check or commit was authorized or performed.

This record corrects the development-owner defect reported in
`2026-11-10-identifier-hmac-credentials-H4K8.md`. The initial temporary preflight compared
`rolcanlogin` to the string `"f"`; ActiveRecord's PostgreSQL result mapping returns Boolean `false`.
It therefore incorrectly rejected valid NOLOGIN roles. An independent read-only check confirmed
the Boolean mapping on both source connections. The temporary preflight now compares to `false`.
The previous claim that these development databases required privilege repair was incorrect.
The separate backlog about schema-loaded databases remains open; this run does not resolve it.

Actual metadata validation passed for all four scopes:

- Function owner equals both its embedded expected owner and the database-specific scoped role.
- Definer and caller have NOLOGIN, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOINHERIT,
  NOREPLICATION and NOBYPASSRLS, no unexpected configuration/memberships, and dependencies only
  in the matching development database.
- Rotation function uses SECURITY DEFINER with the restricted search path; PUBLIC has no
  execution privilege and the matching caller can execute it.
- Definer has the required source ID/digest SELECT, digest-column UPDATE, audit INSERT and audit
  sequence USAGE, without table-wide source UPDATE.
- Audit guards and APP binding guards contain the same expected scoped owner literal.

**No role, grant, function, trigger, schema, migration, credential or schema dump was changed.**
The only privilege-check source correction was in the ignored temporary diagnostic script.

## Executed maintenance

The operational script was `tmp/identifier-hmac-authorized-rotation.rb --execute`, launched in
development through `tmp/credential-safe-command.rb`, with `OPEN_TELEMETRY=false` and all four
lookup ENV names absent. The wrapper redacts known secrets in memory before showing output.
No key values, readable identifiers, lookup digests, connection URLs or row snapshots were printed
or recorded. Preservation comparisons and decrypted-identifier calculations stayed in memory.

1. Validated the exact development database bindings and restricted maintenance metadata.
2. Stopped the existing Foreman process group, including web/jobs, and confirmed all 13 processes
   stopped. The diagnostic process was outside that group.
3. Opened a separate maintenance PostgreSQL connection per realm from its existing configured
   development connection. No new account or membership was created. Each connection began a
   transaction and acquired SHARE locks on both of its identifier tables, with bounded lock and
   statement timeouts. These locks prevent other backends from modifying source rows while
   allowing the application's read-only source queries.
4. Captured every source row's complete non-digest representation in memory and computed expected
   digests with the new credentials. Read prior audit counts without exporting audit rows.
5. Selected each existing scoped caller with `SET LOCAL ROLE` and invoked the public
   `IdentifierHmacEmergencyRotation` service, the same restricted service used by
   `identifier_hmac:rotate`. Its existing SECURITY DEFINER functions performed the updates on the
   lock-owning maintenance connection. Ordinary backfill saves and guard bypasses were not used.
6. Checked all recomputed digests, exact non-digest source equality and corresponding audit-count
   increments before committing. Both realm transactions committed successfully.
7. Re-read committed digests and checked existing email/telephone search, including the APP
   sign-in identity resolver against effective binding ownership. Resumed the process group only
   after all checks passed. No process remained intentionally stopped.

Using the existing public service directly allowed source write locks and function writes to share
the same dedicated backend; a separately spawned Rake task would have opened another backend and
blocked behind those locks. This introduced no new application runtime path. Realm transactions
remain separate: a failure after one commit would require keeping writers stopped and fixing
forward. No such failure occurred.

| Scope | Existing rows | Digests changed | Audit records added | Digest verification | Other source fields |
| --- | ---: | ---: | ---: | --- | --- |
| APP Email | 1 | 1 | 1 | passed | unchanged |
| APP Telephone | 0 | 0 | 0 | empty scope verified | unchanged |
| ORG Email | 1 | 1 | 1 | passed | unchanged |
| ORG Telephone | 0 | 0 | 0 | empty scope verified | unchanged |

The preserved fields include encrypted readable data, ownership, binding/lifecycle facts, OTP
fields and timestamps. The two new audit facts were produced atomically by the existing functions;
no existing audit record was deleted or rewritten. All four service results reported zero failed
records. Committed existing-email lookup and APP sign-in resolver verification passed. No synthetic
retained contact was inserted merely to populate an empty telephone scope.

## Post-maintenance verification and remaining limits

- Corrected read-only preflight: all four scopes report valid scoped NOLOGIN ownership.
- Development web/jobs were resumed; no development supervisor process remains stopped.
- The existing development server returned HTTP 200 for the neutral `/sign?ri=jp` GET after the
  maintenance. No sign-in POST, session issuance or provider delivery was performed.
- No application behavior source changed during this continuation, so the previous 80-test focused
  pass and six-file lint result remain the relevant code verification. This continuation adds
  actual retained-data maintenance and committed lookup evidence; it does not claim another suite run.
- CI cleanup is still blocked by the read-only `.github` mount. The previous security collection's
  three withdrawal HTTP 503 failures were independently reproduced with the old reader code and
  remain outside this maintenance scope. No full CI success is claimed.

The owner approval and retained-data recalculation portion of AC-5 is complete. AC-6 now includes
actual retained-email lookup verification, in addition to the previous synthetic lookup and HTTP
checks. AC-2 CI cleanup and the unrelated security failures remain open in the owning spec.
