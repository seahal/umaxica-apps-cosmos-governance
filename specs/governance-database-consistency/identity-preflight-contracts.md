# Identity uniqueness preflight contracts

Status: implementing

Authority: owner permits coherent internal refactoring; parent execution approved these concrete
KEEP-only units on 2026-11-12. Existing authentication, ownership, encryption and retention contracts
remain authoritative. No OP source schema, Solid Queue, CI or identifier format changes are included.

## Existing blind-index enforcement

Operator email and telephone uniqueness already queries the exact digest and reports errors on
`address` or `number`. Declaring its true Rails validator kind as uniqueness changes no query,
validation or error behavior. The checker must recognize the actual guarded validator against a
stronger scalar `digest IS NOT NULL` unique index. Coverage inference remains conservative for scopes,
associations, unknown explicit predicates and arbitrary partial exclusions; no configuration suppresses
checks. Explicit predicates that cannot be evaluated must not silently become a weaker nil guard.

## Client contact bindings

Only finalized, unreleased rows reserve normalized destinations and owners. Unfinalized candidates
may share either key. Released history remains retained and does not reserve either key. Each
concrete contact model declares the exact partial predicate and candidate eligibility. The specific
framework uniqueness validator delegates Rails' standard indexed-key query, then reports only its
new digest collision on the semantic address/number attribute. It leaves pre-existing errors intact.
Unchanged bindings and releases perform no new uniqueness probe.

Ordinary duplicate finalization now raises RecordInvalid with a field error. Validation-bypassed
inserts/updates and races remain protected by unchanged PostgreSQL unique indexes and binding
immutability triggers. Internal tests change to the authorized preflight behavior while separate
SQL-bypass assertions retain exact PostgreSQL rejection. Proof, owner locking and source-audit order
are not moved by this model validation change.

## Client external identities

The misleadingly named client/provider index actually reserves one unreleased binding per client,
not one per provider. The second unique key is issuer plus deterministically encrypted subject.
Candidate and existing-row predicates both use unreleased status, independently of the display state.
Unreleased consent_revoked/account_deleted rows retain their reservations; released history can
coexist and allow replacement. Model preflight preserves the same tuple and SQL encryption, and
unchanged authentication metadata/release writes add no uniqueness queries. Existing immutable owner,
subject and release triggers remain effective when validation is bypassed.

## Passkey references

The self-generated UUID reference is distinct from the authenticator credential ID. Preserve issued
values, format and owner-specific consumer contracts. Ordinary duplicate reference validation now
fails before persistence. The registration operation retains its owner lock, requires_new transaction,
save-before-audit order and exact database credential-ID classifier. The finalizer re-raises unexpected
reference collisions instead of converting them into a normal credential refusal. Other invalid
credential values retain their existing domain refusal; unrelated PostgreSQL unique failures still
propagate. No retry or identity regeneration is introduced.

## Acceptance

- Actual checker reports recognize correct enforcement without exclusions.
- Public model/operation tests cover candidate classes, release/replacement, duplicate keys, malformed
  values and unchanged-query budgets.
- Real PostgreSQL bypass and independent-worker tests retain the constraints and race guarantees.
- Finalizer refusal/propagation tests use real registration errors and control only the result-delivery
  I/O boundary; they do not claim to prove a complete connected OP ceremony.
- Relevant existing contact, credential, finalizer, integration and concurrency tests pass, followed
  by scoped lint and the parent's full KEEP checker/reconstruction verification.
