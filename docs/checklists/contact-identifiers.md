# Email, Telephone and dead identifier acceptance

Authority: the approved E01–E20 contract and
[realm-separated identifiers ADR](../../adr/realm-separated-identifiers-and-dead-history.md).
Implementation ownership stays with its
[existing plan](../../specs/realm-separated-identifiers-and-dead-history/plan.md), including
approved bounded receipts and transport/proof protections. Checkboxes there are historical claims,
not current results. Each criterion applies separately to Client/app, Visitor/com, Operator/org and
to Email versus Telephone unless it explicitly narrows scope. Follow the
[investigation procedure](integrated-stack.md#independent-investigation); the criteria grant no
deletion, secret rotation or production authority.

## CONTACT-1 — Independent policy and persistent failure accounting

- Basis: E01–E04. Given each concrete identifier with 0, 1, MAX−1, MAX or MAX+1 failures, perform
  first issuance, resend, replacement code, expiry, cancel and logical retirement. None resets
  failures. An admitted wrong comparison increments atomically; only successful normal consumption
  may reset under the channel contract. Test resend below/at MAX and correct consume afterward;
  retain finite locks and destination budgets. A retained receipt cannot reset failures incurred
  later.
- Telephone uses its explicit otp_last_sent_at in every realm, never created_at. Email/Telephone own
  separate stateful lifecycle/attempt/cooldown/resend/retention policies; pure crypto primitives may
  be shared. No shared OtpLockable, shared stateful parent or new global identifier authority.
- APP and ORG Telephone credential-registration issuance accepts the existing negative-infinity
  timestamp and applies the 30-second Source cooldown at the before, equal and after boundaries.
- Check concrete model/policy/issuer callers, schema timestamp and public OTP tests. Start at
  existing `test/models/concerns/otp_lockable_test.rb` only after inspecting its current subject;
  its historical filename does not authorize reintroducing shared policy. Complete six-model
  boundary evidence is planned. Old plan recommendations must be annotated superseded rather than
  silently followed.

## CONTACT-2 — Realm/channel HMAC and maintenance isolation

- Basis: E07, [HMAC rotation ADR](../../adr/identifier-hmac-emergency-rotation.md). Given equal
  normalized identifiers, compute through each realm's model/job/service: same realm/channel is
  stable, app/com/org digests differ, and Email keys do not substitute for Telephone keys.
- Required names are `{APP,COM,ORG}_EMAIL_ADDRESS_HMAC_KEY` and
  `{APP,COM,ORG}_TELEPHONE_NUMBER_HMAC_KEY`. Model or explicit realm selects them, not request host.
  Missing required keys fail closed without old global SALT fallback or secret-bearing errors.
- Governance APP/ORG live Email/Telephone HMAC keys come from encrypted Rails credentials only,
  including when a same-named ENV entry is present. Missing or blank credentials fail explicitly;
  ENV is neither a fallback nor an override for these four keys. History-key reuse checks compare
  against the same authoritative credential source. Basis: owner decision dated 2026-11-10 in
  `docs/backlog/2026-11-10-secrets-from-credentials-only.md`; this does not change other key
  families.
- Exercise an authorized isolated com-Telephone maintenance case: app/org and Email are unaffected;
  ordinary roles cannot use maintenance to alter finalized owner/PII/binding facts. No real secret
  changes are authorized by this criterion.
- Check [realm rotation tests](../../test/services/realm_identifier_hmac_rotation_test.rb),
  [maintenance boundary tests](../../test/services/identifier_hmac_maintenance_boundary_test.rb),
  normalization and missing/malformed-key cases. Required environment wiring is verified by safe
  direct boot/configuration evidence, not an added setup unit test.

## CONTACT-3 — Realm encryption ownership and rotation

- Basis: E08, realm ADR and [PII inventory](../security/identifier-encryption-inventory.md). Given
  each of the six identifier models encrypted with its owning realm's current/previous keyring, read
  previous ciphertext and write new ciphertext. Reads stay within the owning realm; writes use its
  current key. Missing/malformed required configuration refuses explicitly without a global
  fallback.
- Do not silently migrate unrelated/shared PII to app by database location. Preserve the accepted
  inventory's six-identifier scope and separately owned non-identifier keyring. Previous-key
  capability stays available; errors/evidence reveal no secrets and normal test boot needs no ad hoc
  key defaults.
- Check [encryption tests](../../test/models/realm_identifier_encryption_test.rb),
  [rotation drill](../../test/integration/identifier_encryption_rotation_drill_test.rb), provider
  source and actual safe boot. Historical counts/boot results are not current evidence.
  Non-identifier PII reassignment is outside this criterion.

## CONTACT-4 — Ceremony ownership, binding and single use

> **Superseded for Governance runtime (2026-11-13, owner):** The Governance-local Email/Telephone
> OTP ceremony execution, result consumption and queued proof delivery described by this criterion
> are retired. Access owns authentication ceremony execution. This is not evidence that an Access
> replacement API is implemented or verified. Contact identity, encryption, failure-accounting,
> audit and retention records remain; this code change did not alter schema or persisted data.

## CONTACT-5 — Bound transport and legacy retirement

> **Superseded for Governance runtime (2026-11-13, owner):** Governance-local OTP transports and
> ceremony-bound payload readers are retired where they had no application caller; no local legacy
> fallback remains. Access owns ceremony execution, but its replacement delivery contract is not
> established by this checklist. Physical database columns and historical records are unchanged by
> this work and require a separate ownership/schema review before cleanup. No delivery or
> external-provider behavior is claimed here.

## CONTACT-6 — Live uniqueness without dead reservations

- Basis: E01/E09/E12. Given normalized-equivalent Email (case/whitespace) or formatted Telephone,
  race two creates in each realm using independent DB connections. At most one live binding exists
  in its proper namespace; conflicts roll back cleanly. Another realm may independently use the same
  value without correlation/global lookup.
- Race active deletion and new creation, then reuse a physically dead identifier for the
  same/different identity. Live uniqueness remains correct while history neither blocks reuse nor
  authenticates it. Use semantic status constants; logical deletion/retention must not be
  misclassified as irreversible dead history. Preserve Email/Telephone domain-specific live
  predicates rather than guess a common one.
- Check actual unique constraints and public concurrency tests; start with
  [purge concurrency](../../test/operations/dead_identifier_purge_concurrency_test.rb). Full
  normalized create/delete matrix for all six models is planned where missing; a model validation is
  insufficient. The current six-model public model collection passed
  `126 runs, 405 assertions, 0 failures, 0 errors, 0 skips`; see
  [`T6N4`](../../evidence/2026-10-12-p3e-live-uniqueness-T6N4.md). That collection is current
  evidence, not a claim that every realm/status/concurrency partition is closed.

## CONTACT-7 — Minimal irreversible history and atomic purge

- Basis: E10–E12/E18. Given a live, logically deleted, recoverable or retained identifier, ordinary
  lifecycle activity produces no History. Only permitted irreversible physical purge locks fresh
  owner/ source, fingerprints persisted original PII, inserts history and deletes source in one
  owning-DB commit. Inject refusal after insert and race duplicate purge: rollback leaves both
  original source and prior history unchanged; one actual purge produces exactly one archive, not
  one per retry.
- Six independent models use only id, user_id/visitor_id/staff_id, fingerprint, attached_at,
  detached_at, created_at. No public_id, status, updated_at, raw/encrypted identifier, live digest
  or source public ID. No shared parent model or Avatar-style live ownership reconstruction. The
  implementation exposes separate explicit lifecycle boundaries: irreversible purgers authorize
  `purge_with_dead_history!`, ordinary identifier removal uses `destroy_without_dead_history!`, and
  an unmarked persisted destroy is refused. Owner-dependent whole-Identity erasure remains its
  separate history-deleting contract. Raw/bulk deletion paths cannot silently bypass the required
  boundary; callback presence alone does not prove that.
- Check [schema contract](../../test/models/dead_identifier_history_contract_test.rb),
  [destroy tests](../../test/models/dead_identifier_destroy_test.rb),
  [purge tests](../../test/operations/dead_identifier_purge_test.rb) and purge concurrency with
  actual PostgreSQL rollback/commit. Model-less/source paths must also be accounted for; no
  real-data purge. The six identifier table catalogs in the current disposable rehearsal have no
  retired identifier-owned OTP columns or source-proof contexts, and no constraint, non-internal
  trigger or public function still references them; see
  [`U4K6`](../../evidence/2026-10-12-p3d-schema-retirement-U4K6.md). Historical migrations and
  rejection fixtures remain traceability material; this catalog result does not close the full
  transport/source/fixture/constraint inventory. The current seven-file history/retention collection
  passed `96 runs, 776 assertions, 0 failures, 0 errors, 0 skips`; see
  [`V3M7`](../../evidence/2026-10-12-p11a-history-matrix-V3M7.md). It covers the available six-model
  history schema, visibility, fingerprint, retention, destroy/purge and concurrent purge checks, but
  does not close the remaining cross-database fault, whole-owner/legal-retention and complete
  six-model create/purge partition. The integrated history, retention, HMAC and encryption
  collection passed `110 runs, 1066 assertions, 0 failures, 0 errors, 0 skips`; see
  [`X7Q4`](../../evidence/2026-10-12-p11a-integrated-matrix-X7Q4.md). This is current focused
  evidence and does not authorize real-data purge or close the remaining source/fixture,
  cross-database, whole-owner/legal-retention or D-11 matrix gaps.

## CONTACT-8 — Fingerprint cryptography and repeated history

- Basis: E12/E13. Given a normalized candidate, derive domain-separated HMAC with one of
  `{APP,COM,ORG}_{EMAIL,TELEPHONE}_HISTORY_KEY`, distinct from live lookup secrets, then randomly
  salted Argon2id at the accepted pinned cost. Authorized identity-scoped matching recognizes the
  candidate; DB-only offline guesses do not have the necessary secret. No plain SHA/reversible
  representation.
- Register/purge the same value repeatedly: multiple history rows are allowed with no fingerprint
  UNIQUE or standalone fingerprint index. No all-users find_by_fingerprint, authentication/recovery
  lookup, cross-realm correlation or restoration from history. Invalid fingerprints/inputs and wrong
  realm/channel/key refuse safely, without reducing crypto parameters for tests.
- Check
  [fingerprint verifier tests](../../test/lib/identifier_history_fingerprint_verifier_test.rb),
  actual schema, matching callers and current Argon2 source/cost configuration. Tests of known
  fixtures plus cryptographic construction review are evidence; brute-force timing samples do not
  prove anonymity. The current focused history matrix also includes the verifier and repeated-row
  checks; see [`V3M7`](../../evidence/2026-10-12-p11a-history-matrix-V3M7.md). The integrated
  history, retention, HMAC and encryption collection passed
  `110 runs, 1066 assertions, 0 failures, 0 errors, 0 skips`; see
  [`X7Q4`](../../evidence/2026-10-12-p11a-integrated-matrix-X7Q4.md). These are current focused
  results, not proof that every realm/channel maintenance and legal retention partition is complete.

## CONTACT-9 — Internal visibility and privacy lifecycle

- Basis: E14–E16/E20, realm ADR. Given ordinary Web/BFF/native/public API/export/activity/MCP
  access, dead history is not returned. Only required server code and explicitly authorized
  Operator/legal/ audit/privacy procedures can inspect it. No advertising, recommendation, profiling
  or cross-realm matching, IP/UA/partial identifier/request-param enrichment.
- History is pseudonymous personal data, not anonymous. Identity-scoped candidate matching and an
  identity FK remain sensitive. Product invisibility does not assert absolute legal nondisclosure.
  Existing legal holds/retention/protections control allowed erasure; indefinite PII retention and a
  new per-row legal_hold flag are not assumed. Identifier-only purge retains its identity/history;
  approved whole-identity erasure follows its separate guarded contract. Avatar history is
  unaffected.
- Check
  [visibility invariant](../../test/security/invariants/dead_identifier_history_visibility_invariant_test.rb),
  [retention tests](../../test/jobs/dead_identifier_retention_test.rb), routes/serializers/export
  paths and hold/whole-owner tests. The current seven-file history/retention collection passed
  `96 runs, 776 assertions, 0 failures, 0 errors, 0 skips`; see
  [`V3M7`](../../evidence/2026-10-12-p11a-history-matrix-V3M7.md). The integrated history,
  retention, HMAC and encryption collection passed
  `110 runs, 1066 assertions, 0 failures, 0 errors, 0 skips`; see
  [`X7Q4`](../../evidence/2026-10-12-p11a-integrated-matrix-X7Q4.md). Planned gaps stay explicit. No
  application dynamic access or legal policy compliance is certified by the document alone; unknown
  legal conditions cannot authorize deletion.
