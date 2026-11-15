Task (umaxica-apps-cosmos-governance only): design the lifecycle of a registration that starts in
Access's Auth ceremony and is owned by Governance, so that an interrupted browser never leaves an
unowned or half-made account. Design only: produce an ADR (or an amendment of an existing one), a
state diagram with its transition inventory, and a report. No application code, no migration. No
commit. Never print secrets or environment values. Never edit config/credentials/*.yml.enc.

This container sees only this repository. Facts from Access and Jump are written below; do not look
for sibling checkouts. Earlier implementations are in this repository's history (`git log`,
`git show <commit>:<path>`).

## Decision

Owner, 2026-11-14: this is the item that hurt most in the previous implementation; design it before
the Stage 4 handoff is built. Owner quote: "それだいじだね。前の実装の時は散々苦労したからね。"

## Fixed context (decided, do not reopen)

- Access and Governance share no database, cookie or session. They exchange signed PS256 JWS carried
  by the browser through Jump (`jump.umaxica.net`); no server-to-server call. The only server-side
  read between them is the peer's published JWKS (Base and Auth each publish
  `/.well-known/jwks.json` per realm). Access asks; it fails closed without a valid answer.
- Payloads stay small (Jump: destination URL at most 2048 characters, `rt` at most 4096; a PS256
  signature alone is 512 characters). Credential IDs or one looked-up credential, not lists.
- RPs send no `prompt=create`; sign-in and sign-up share one neutral entry. Org has no public
  sign-up.
- Operations on data are by the person themself only for now; tokens carry actor and subject as
  separate claims and refuse when they differ, so delegation can be added later.
- The old server-pushed revocation path is being removed (Access order of 2026-11-14).

## Observed on 2026-11-14 in this repository

- `ClientStatus` has `PENDING`, `UNVERIFIED_WITH_SIGN_UP`, `VERIFIED_WITH_SIGN_UP`, `GHOST`,
  `RESERVED` among others; `ClientRegistrationCompletion` and `ClientRegistrationCompletionMethod`
  exist.
- ADRs present: `sign-in-first-and-sign-up-handoff.md`,
  `sign-up-authentication-handoff-and-social-rt.md`, `sign-up-checkpoint-turnstile-boundary.md`,
  `sign-up-cycle-cancellation-retention.md`, `sign-up-finalization-in-auth.md`,
  `sign-up-flow-admission-binding-and-cardinality.md`,
  `sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md`. Several were written when
  Access owned the account; check each against the split (Governance owns accounts and credentials;
  Access owns OP sessions, tokens and the Auth ceremony screens).

## Work

1. Inventory: for every status, model and ADR above, say who writes it today, who should write it
   after the split, and what the history shows went wrong before (look for reverted or repeatedly
   patched commits about sign-up, cancellation, duplicates and cleanup; summarise causes, not
   diffs).
2. Design one lifecycle, owned by Governance, covering at least: start (who creates the pending
   record, when, and bound to what browser-side nonce); identifier claim (email or telephone
   uniqueness while pending; what happens when the same identifier is pending twice, or already
   active); credential registration in Auth and its delivery to Governance (one handoff, single use,
   `jti` consumed atomically with the state change); completion; cancellation by the user; expiry
   and cleanup of abandoned records (deadline, job, idempotency, audit record); browser interruption
   at every step (Back, second tab, closed tab, Jump failure, Access session expiry, Governance
   session expiry, key rotation, late duplicate); retry after failure that never repeats completed
   work; what the "already done" page may reveal.
3. Write the result as an ADR amendment (prefer amending the existing sign-up ADRs over a new one;
   say which supersede which), plus `docs/mermaid/` diagram and transition inventory for the axis,
   linked from `docs/mermaid/README.md`. NULL never encodes a state.
4. List what Access must send and receive for each step (purpose, claims, TTL, size estimate),
   without inventing Access internals; mark each as a requirement for the Access side.

## Stop and report

Owner items only where ADRs, code and the fixed context above cannot answer (for example the
abandonment deadline, or whether a pending identifier blocks a second sign-up). Give options and a
recommendation for each.

## Report

`evidence/YYYY-MM-DD-pending-registration-lifecycle-design-XXXX.md` (full `git rev-parse HEAD`):
inventory, history findings, chosen lifecycle summary, files written, Access requirements, owner
items, confirmation that no code, migration or credentials file changed.
