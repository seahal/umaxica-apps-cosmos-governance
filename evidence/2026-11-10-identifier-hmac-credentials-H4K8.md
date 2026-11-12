# Governance live identifier HMAC credentials

Date: 2026-11-10
Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`
Scope: owner request dated 2026-11-10; decision in
`docs/backlog/2026-11-10-secrets-from-credentials-only.md`;
acceptance in `specs/governance-identifier-hmac-credentials/spec.md`.

The worktree already contained extensive unrelated uncommitted changes, including development
credentials and the container environment file. Results describe that worktree plus this scoped
change, not a clean checkout of HEAD. Existing unrelated changes were preserved. No commit,
development database reset/deletion, retained-data backfill, role change or schema change occurred.

## Configuration inventory and completed changes

The four names are `APP_EMAIL_ADDRESS_HMAC_KEY`, `ORG_EMAIL_ADDRESS_HMAC_KEY`,
`APP_TELEPHONE_NUMBER_HMAC_KEY` and `ORG_TELEPHONE_NUMBER_HMAC_KEY`.

Before editing, definitions were found in:

- `.env`: four definitions, originally lines 242–245; loaded by
  `config/boot.rb` / `LocalEnvironment.load!`.
- `.env.container.devcontainer`: four definitions, originally lines 215–218; supplied to the core
  container through `.devcontainer/compose.yaml`'s `env_file`.
- `.github/workflows/ci.yml`: four definitions in each of two job environments, originally
  lines 373/375/376/378 and 657/659/660/662.
- The current executor inherited all four names from its container environment. No additional
  direct definitions were found in inspected Compose/devcontainer configuration.

Eight independent values were generated locally using `SecureRandom.hex(32)`, one per key and
environment. All eight were distinct from each other and the previous inherited local values.
They were added to `config/credentials/development.yml.enc` and `test.yml.enc` using the installed
ActiveSupport encrypted-configuration API. Decrypted YAML remained in memory. A readback compared
all entries with the expected original entries plus the four additions in each environment.
Unrelated credential entries were preserved. No keys, secret values or secret fingerprints are
recorded here.

All four definitions were removed from `.env` and `.env.container.devcontainer`, preserving other
lines. A subsequent scan found zero target-name occurrences in those two files.

The installed Rails `Rails.app.creds` uses ENV-first CombinedConfiguration. The two relevant
application readers therefore use `Rails.app.credentials.option` directly:

- `app/lib/identifier_blind_index.rb`: removes explicit ENV fallback and refuses missing/blank keys.
- `app/lib/identifier_history_fingerprint_verifier.rb`: live-key collision checking uses the same
  credential source; it no longer reads these live keys from ENV. Dedicated history keys and
  every other secret family remain outside scope.

Affected tests now stub the encrypted credential backend. They cover all four keys, conflicting
ENV, missing/empty/whitespace credentials, realm/channel separation, history-key separation and
maintenance behavior. Existing email fixture files are empty or metadata-only; no fixture rewrite
was needed. The full focused run exercised the existing backfill tests with the new test keys.

An in-memory inspection confirmed eight distinct 64-character lowercase hexadecimal values and
no occurrence of a new plaintext key in the edited source, documentation or tests. The final
artifact check also covers this evidence and the specification. Verification subprocesses removed
the four inherited ENV names; output was redacted in memory before display. Temporary scripts
under `tmp/` contain code only, not credential values or raw captured logs.

## Verification observations

Commands below were invoked through `tmp/credential-safe-command.rb`, which unsets the four names
for child processes and redacts known secret strings in memory before displaying command output.

```bash
bin/rails test test/lib/identifier_blind_index_test.rb \
  test/lib/realm_identifier_digest_test.rb \
  test/lib/identifier_history_fingerprint_verifier_test.rb \
  test/services/realm_identifier_hmac_rotation_test.rb \
  test/services/identifier_blind_index_backfill_test.rb \
  test/services/identifier_hmac_maintenance_boundary_test.rb \
  test/queries/passkey_sign_in_identity_resolver_query_test.rb
bin/rails test test/security
bin/rubocop app/lib/identifier_blind_index.rb \
  app/lib/identifier_history_fingerprint_verifier.rb \
  test/lib/identifier_blind_index_test.rb test/lib/realm_identifier_digest_test.rb \
  test/lib/identifier_history_fingerprint_verifier_test.rb \
  test/services/realm_identifier_hmac_rotation_test.rb
```

- Focused behavior: **80 runs, 568 assertions, 0 failures, 0 errors, 0 skips**.
- Security collection: **126 runs, 748 assertions, 3 failures, 0 errors, 0 skips**. Failures are
  `WithdrawalGateInvariantTest`'s closing-resource redirect and allowlist-reachability cases, and
  `OrgWithdrawalGateInvariantTest`'s closing-operator redirect case. All received HTTP 503.
- Control: in a disposable test process only, loaded the two original application implementations
  from HEAD, leaving the rest of the worktree/configuration unchanged. Running the two failing
  test files reproduced the same three HTTP 503 failures: **7 runs, 21 assertions, 3 failures,
  0 errors, 0 skips**. This isolates the changed reader implementations from these existing
  failures; it is not a clean pre-change/full-repository baseline. No security assertion was weakened.
- Scoped RuboCop: **6 files, no offenses** after correcting two formatting offenses introduced
  while editing tests. Scoped `git diff --check` passed.
- Fresh development process, with `OPEN_TELEMETRY=false` and all four lookup ENV names absent:
  boot passed. Within read-only transactions, a synthetic email passed through
  `ClientSecretIdentityResolverQuery.call`, `ClientEmail.find_by_address` and
  `OperatorEmail.find_by_address`, returning no record without a configuration error.
- A fresh loopback-only Puma on port 3011 returned **HTTP 200** for the neutral sign-in GET with
  `ri=jp` and a modern browser User-Agent; it was then stopped. Initial probes without this request
  context returned HTTP 302, not a credential error. No sign-in POST, session issuance or OTP
  delivery was attempted.
- `RAILS_ENV=development bin/rails restart` refreshed the existing development workers. A local GET
  to the existing port 3000 returned **HTTP 200** for `/sign?ri=jp`. Development boots also emitted
  an existing MessagePack early-load warning, which was not changed in this task.

These synthetic reads prove the new source works without inherited lookup ENV. They do not prove
that existing accounts are searchable: their retained digests have not been recomputed. No
provider check or full CI gate was run. Production/staging integration was not tested or changed.

## Remaining CI source blocker

Writing `.github/workflows/ci.yml` failed with `EROFS`. `findmnt` reports the repository's `.github`
subtree mounted **read-only**. Its eight definitions remain; the application now ignores them for
live lookup, but AC-2 source cleanup is incomplete. The mount restriction was not bypassed.

When the file is writable, remove only mapping lines defining the four named keys from both job
environments, preserve COM/other settings, and verify zero remaining definitions. Do not include
the removed values in a patch/report. The current executor's inherited old ENV cannot be removed
from its parent process: recreate the container from the cleaned configuration when operationally
appropriate. New lookup code ignores those inherited values; verification children unset them.

## Retained development DB procedure: prepared, not executed

The requested `identifier_blind_index_backfill` is a service, not a Rake task. Its ordinary
invocation is shown for identification only, **not approved for retained-data execution**:

```bash
bin/rails runner -e development 'result = IdentifierBlindIndexBackfill.new.call; puts result.to_h'
```

It visits all four identifier models, updates via `save!(validate: false)`, runs callbacks and
changes timestamps. There is no dry-run or outer transaction; a failure can leave partial changes.
Finalized binding guards may reject ordinary digest changes. The accepted
`adr/identifier-hmac-emergency-rotation.md` instead requires the dedicated restricted maintenance
path. Do not disable triggers, add a bypass or reset the database to make the ordinary service work.

A read-only catalog preflight against development found all four rotation functions present, but
**none had the required scoped NOLOGIN definer owner**. This is a concrete execution blocker,
consistent with `docs/backlog/2026-10-25-identifier-hmac-definer-role-in-loaded-schema.md`.
No function was invoked and no owner, grant or schema was changed. Repairing that deferred
privilege boundary needs separately scoped owner authorization; backfill approval alone does not
authorize DDL/role repair or bypassing the owner checks.

Proposed safe sequence, subject to owner approval and verified prerequisites:

1. Freeze all four affected identifier write paths, including background/admin writers, throughout
   the mixed-digest interval. Old and new digests cannot enforce logical uniqueness together.
2. Resolve the maintenance-owner defect through the separately approved migration/privilege
   workflow; verify function ownership, restricted caller membership and unchanged guards. Supply
   `IDENTIFIER_HMAC_MAINTENANCE_DATABASE_URL` securely for the matching APP/ORG source database.
   Do not print or record a URL or grant generic owner/definer privileges as a shortcut.
3. After explicit approval, execute each selected scope using the existing task, selecting the
   corresponding secure APP or ORG maintenance connection before each command:

   ```bash
   RAILS_ENV=development bin/rails 'identifier_hmac:rotate[app,email]'
   RAILS_ENV=development bin/rails 'identifier_hmac:rotate[app,telephone]'
   RAILS_ENV=development bin/rails 'identifier_hmac:rotate[org,email]'
   RAILS_ENV=development bin/rails 'identifier_hmac:rotate[org,telephone]'
   ```

4. Compare every retained readable identifier's recomputed digest in memory with its stored
   digest, emitting aggregate mismatch/failure counts only. Confirm zero failures/mismatches,
   preserved ownership/ciphertext/lifecycle facts and expected atomic audit records. Restart
   readers and verify existing-account lookup before reopening writes.

The dedicated path changes only the selected digest and atomically records a non-PII audit fact
per changed row. It has no all-scopes transaction: on partial failure, keep affected writes frozen,
retain the new keys and audits, investigate, then retry idempotently. Do not restore old exposed
keys, delete audit history, disable guards or reset/delete the DB. No backup of readable PII or
old keys was created by this task.

## Acceptance disposition

- AC-1: passed; all eight keys generated and encrypted independently, other entries preserved.
- AC-2: application/local environment migration passed; CI definitions blocked by read-only mount.
- AC-3: passed in focused behavior checks; no fixed real key value is required by the edited tests.
- AC-4: focused tests/lint passed; full security run retains the three independently reproduced failures.
- AC-5: procedure/risk/recovery prepared; owner approval and maintenance privilege repair outstanding.
- AC-6: fresh and restarted development HTTP checks and read-only synthetic lookup passed;
  existing-account recovery remains unverified until approved retained-data maintenance completes.
