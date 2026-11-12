# Completion, Secret claim and authority-lock uniqueness

Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`.
These observations include uncommitted task changes and pre-existing split work.
Final implementation scope: four KEEP Zenith models; Secret claim preflight remains deferred; no schema, CI, Solid Queue or other database changes.

## Contract review

- ClientRegistrationCompletionMethod is an immutable seeded four-row catalog. Its migration creates
  a smallint primary key and a CHECK allowing exactly (1,email), (2,telephone), (3,google), (4,apple).
  Actual PostgreSQL inspection confirmed that CHECK is validated and the rows match exactly. The
  PrimaryKeyTypeChecker recommendation to widen this ID does not establish a defect; all legal IDs
  fit smallint. The finding remains a genuine bounded-catalog recommendation, not a waived schema
  constraint or an approval to alter IDs.
- ClientRegistrationCompletion is an immutable historical receipt. Current application references
  read and verify it; no application creation/retry writer remains. Its independent client,
  public-reference and signup-flow unique indexes remain intact. Creation-only preflight adds
  model errors without extra uniqueness probes when validating unchanged persisted receipts.
- ClientSecretCredential claim operation and durable signin-flow references remain unchanged. The
  initial preflight trial exposed an audit atomicity risk: commit_sign_in_claim! records a source
  event before save!, and RecordInvalid does not abort the surrounding transaction as a database
  uniqueness violation does. A caller rescuing it could commit audit without claim. A savepoint
  would need verification through a legal admitted OP handoff, using ClientSignInFlow,
  ClientAuthCeremonySession and ClientOidcAuthorizationTransaction (all TRANSFER OP persistence)
  plus an independent open Zenith transaction. Existing tests exercise refusal only; there is no
  connected application caller or ready legal-claim fixture. Under parent direction, the two trial
  validators and the newly authored incomplete trial test file were removed. No existing test or
  assertion was removed or weakened. The two checker findings remain pending; indexes, guards and
  source-audit order are preserved rather than claiming an unverified atomicity improvement.
- Authority lock acquisition uses create_or_find_by! followed by the existing owner-scoped locked
  lookup. A plain uniqueness validator breaks that API when a competing row is seen before insert.
  The recovery now accepts only RecordInvalid for the matching lock model with exactly one error:
  the owner foreign key is taken. Missing owners and all unrelated invalid records still fail.
  The database RecordNotUnique recovery in create_or_find_by! remains effective. No insert_all,
  validation bypass, retry loop, authorization change or lifecycle order change was introduced.

## Verification so far

- New focused Red command: `bin/rails test test/models/registration_completion_uniqueness_test.rb
  test/models/authority_lock_uniqueness_test.rb
  test/models/authority_lock_acquisition_concurrency_test.rb
  test/models/client_secret_claim_uniqueness_test.rb`.
- Red result: eight tests, seventeen assertions, five failures, zero errors/skips. Four failures
  demonstrate missing model preflight. The fifth exposed a pre-existing missing client label when
  RecordInvalid rendered an absent owner; parent integration owns that translation correction.
- Retained tests exercise ordinary duplicates, validation-bypassed PostgreSQL uniqueness, unchanged-record
  query budgets, invalid owners, public repeated lock acquisition and two independent transaction
  workers acquiring the same newly committed lock on each surface.
- Green command retained the three completion/lock files above. Result: seven tests, 54 assertions,
  zero failures/errors/skips, including concurrent acquisition on both account surfaces. An additional
  test added after initial Red verifies unchanged lock validation adds no uniqueness SELECT.
- RuboCop final seven-file lint: zero offenses. Scoped diff-check passed. Broader public lock
  writer regressions remain parent aggregate verification (authority_lock_test,
  client_persona_creator_concurrency_test, authority_owner_family_cutover_concurrency_test).
- Initial missing-owner translation failure was resolved by parent-owned client/operator labels;
  the actual Green now demonstrates the original RecordInvalid contract for nil/nonexistent owners.
- Final checker and aggregate outcomes remain parent integration responsibilities.

## Erratum: catalog primary-key classification

The earlier bounded-catalog inference was incorrect. Reinspection of accepted
`adr/identifier-contract.md` and durable `docs/checklists/identifier-contracts.md` ID-1 establishes
that every UMAXICA-owned persistent table, explicitly including fixed status/catalog tables, has
an actual SQL bigint sole primary key. A fixed catalog may omit a sequence, not the required width.
The observed validated four-value CHECK and actual smallint width remain accurate observations;
they do not establish compliance. The PrimaryKeyTypeChecker finding for this catalog is therefore
a real contract defect, not a genuine false positive. Parent integration owns the proposed widening
and preservation verification for IDs, matching foreign-key column, and existing references.
