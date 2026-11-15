# Pending Registration Lifecycle Design

Date: 2026-11-14  
Repository: `umaxica-apps-cosmos-governance`  
HEAD: `eedf4f51e1e10517ac77381f6a1a03b58b984e71`  
Work order: `plans/2026-11-14-pending-registration-lifecycle-design-work-order.md`  
Worktree: 1,334 changed or untracked paths at task start, matching the front-channel ID Token
evidence (`FCHB`). There were 1,342 at the end, including this file. The additions are the
documentation files listed below. This is a design-only order. No commit, push, deploy or external
change was made.

## Takeover state check

- The FCHB order was already finished. Its evidence was the newest file in the tree (16:58 UTC). No
  file in `app`, `lib`, `db`, `config`, `test`, `src` or `gait` was newer.
- The path count matched the evidence. No half-finished edit was found, so nothing was finished or
  reverted.

## Inventory

| Item                                                    | Writer before the split (history)                                                                                                                                                     | Writer today                                                                                                             | Writer after the split (this design)                                                                                      |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `ClientStatus::UNVERIFIED_WITH_SIGN_UP`                 | The Auth code in this repository wrote it on the pending Client at sign-up start (`SignUpSocialPendingClientSupport`, email/telephone pending principal paths; seen at `efdcd80d31`). | None. The ceremony code was removed on 2026-11-13 (`Q7M2`). `Client::UNFINISHED_REGISTRATION_STATUS_IDS` still reads it. | None. No pending Client exists, because the pending state lives in `ClientRegistration`. Existing rows keep their value.  |
| `ClientStatus::VERIFIED_WITH_SIGN_UP`                   | `Client#finalize_email_sign_up!` / `#finalize_telephone_sign_up!` and `IdentityEmailCeremonyFinalCommitter`, at the decisive commit. Never moved on to `ACTIVE`.                      | None. It is still read by login, recovery and `AuthMethodGuard` status sets, together with `VERIFIED`/`ACTIVE`.          | None, if O-5 is accepted: completion writes `ACTIVE`.                                                                     |
| `ClientStatus::PENDING`, `GHOST`                        | No writer found at `efdcd80d31` or in the current tree.                                                                                                                               | None.                                                                                                                    | Not a sign-up state; untouched. The meaning is undocumented, so retiring either value needs its own decision.             |
| `ClientStatus::RESERVED`                                | No sign-up writer. It is a login-blocked state (`Client::LOGIN_BLOCKED_STATUS_IDS`).                                                                                                  | Read only.                                                                                                               | Not a sign-up state; untouched.                                                                                           |
| `ClientRegistrationCompletion`                          | `AppSignUpRegistrationCommitter`, inside nested OP (`op_base_app`) and Zenith transactions, keyed by `sign_up_flow_ref` = OP Flow public ID.                                          | None (read-only model retained).                                                                                         | The Governance completion transaction, keyed by `sign_up_flow_ref` = registration public ID (21 characters, same column). |
| `ClientRegistrationCompletionMethod`                    | Reference rows (`email`, `telephone`, `google`, `apple`).                                                                                                                             | Reference rows.                                                                                                          | Reused as the registration `method_id`.                                                                                   |
| ADR `sign-in-first-and-sign-up-handoff.md`              | Written when one monolith held Base and Auth.                                                                                                                                         | Accepted.                                                                                                                | Kept; split note added.                                                                                                   |
| ADR `sign-up-authentication-handoff-and-social-rt.md`   | Acme/Sign era; partly superseded already.                                                                                                                                             | Historical in parts.                                                                                                     | Pending-registration release, cleanup ownership and failure domains restated in the amendment.                            |
| ADR `sign-up-checkpoint-turnstile-boundary.md`          | Auth checkpoint routes in this repository.                                                                                                                                            | Routes gone.                                                                                                             | Checkpoint routes and Turnstile belong to Access. The authority rule is kept as Governance ingress.                       |
| ADR `sign-up-cycle-cancellation-retention.md`           | OP Flow states and `SignUpExpiryJob`.                                                                                                                                                 | Historical (2026-11-13 note).                                                                                            | Principles kept; states replaced.                                                                                         |
| ADR `sign-up-finalization-in-auth.md`                   | Auth finalizes, under an OP lock, into Zenith.                                                                                                                                        | Historical runtime.                                                                                                      | Amended. It now holds the proposed design and supersedes decisions 1, 3, 4, 5 and 8.                                      |
| ADR `sign-up-flow-admission-binding-and-cardinality.md` | OP Admission/Binding/Flow cardinality.                                                                                                                                                | Historical (2026-11-13 note).                                                                                            | Belongs to Access. Its D14 item is answered for registration.                                                             |
| ADR `sign-up-one-day-minimum-age-...`                   | `SignUpEligibilityPolicy`.                                                                                                                                                            | Accepted.                                                                                                                | Kept. Governance evaluates it at the start handoff.                                                                       |

## History findings (causes, not diffs)

Commit messages here are mostly checkpoints, so causes come from the repository's evidence records
and from the files' commit counts. Commit counts: `IdentitySocialCeremonyFinalCommitter` 17,
`SignUpStepGate` 16, `SignUpArtifactCleanup` 13, `SignUpTermination` 10. No reverted commit about
sign-up was found; the problems were patched repeatedly instead.

1. **Pending rows blocked retries.** A contact marked verified before required setup finished left
   the identifier unusable after abandonment. A telephone number verified before the passkey step is
   the example. This is recorded in `sign-up-authentication-handoff-and-social-rt.md` and led to the
   cleanup and expiry machinery.
2. **One registration across two databases.** The OP Flow and the Zenith principal needed ordered
   locks and compensating cleanup. Lock-order defects were reproduced and fixed several times (Flow
   held while waiting on the principal; a stale binding read before the lock). Partial cleanup was
   reproduced before atomic cleanup (`A6C4`, `LQ7M`).
3. **Lost commit acknowledgements and retries.** An exact retry after a committed write
   returned 409. A recovery path lost its distribution destination, and duplicate-effect risks
   needed dedicated tests (`E7R4`, `D4Q8`, `R7M2`).
4. **A second writer bypassed the canonical path.** Social sign-up committed at Base and issued the
   OIDC result directly, skipping Sign In First. It needed `sign-up-finalization-in-auth.md` to
   correct it.
5. **Browser and attempt confusion.** An earlier attempt in the same browser was not detected
   (`P7R3`). Back navigation could reset entry state (`P7M2`). Browser nonce checks compared a
   public ID (`5N8C`).
6. **Deadline and race gaps.** The curfew exit was called without its binding (`R6N2`).
   Delivery/cancel and OTP digest races needed independent-connection tests (`N8R4`, `Y8C3`).
7. **Vocabulary drift.** `FAILED` absorbed cancel, block and error. `VERIFIED_WITH_SIGN_UP` was
   never moved to `ACTIVE`, so readers had to accept several "active" values.

The design answers these: one owner, database and commit (2, 3); no account rows before completion,
and supersession by fresh proof (1); one writer and Sign In First kept (4); independent browser
binding on both sides with one pending per browser (5); request-time deadline under the row lock and
a single transaction (6); and the canonical lifecycle vocabulary with an explicit status (7).

## Chosen lifecycle (summary)

- **Owner and axis.** Governance's `ClientRegistration` in `app_zenith`, with one NOT NULL
  `status_id`. The states are `CREDENTIAL_PENDING` (the only in-progress state), `COMPLETED`,
  `CANCELLED`, `EXPIRED` and `HALTED`.
- **Start (H1).** Access sends it after verifying the identifier and collecting the birthdate.
  Governance checks eligibility and supersedes the browser's or identifier's pending registration.
  It creates the row with a user handle, the Access ceremony digest and the digest of a new
  `__Host-` cookie secret. Methods without an Auth credential complete in the same transaction.
- **Completion (H3).** One credential. The `jti` receipt, the account rows, the completion receipt,
  the audit outbox and the transition commit in one `app_zenith` transaction on the database clock.
- **Cancel (H5).** Cancel sets `CANCELLED`. **Expiry.** It is checked at request time and by a
  five-minute sweep. **Purge.** A separate job deletes terminal rows after `purge_after`. **Audit.**
  Chronicle events go through the same-transaction outbox.
- **Interruptions.** Every listed interruption maps to `replay`, `conflict`, supersession or expiry,
  and none repeats completed work. The "already done" page reveals completion only to the bound
  browser.

## Files written

- `adr/sign-up-finalization-in-auth.md`: status note and the "Cosmos split amendment" section
  (design, handoffs, lifecycle, interruptions, storage target, Access requirements, supersession
  map, owner items).
- Pending supersession notes:
  - `adr/sign-in-first-and-sign-up-handoff.md`
  - `adr/sign-up-authentication-handoff-and-social-rt.md`
  - `adr/sign-up-checkpoint-turnstile-boundary.md`
  - `adr/sign-up-cycle-cancellation-retention.md`
  - `adr/sign-up-flow-admission-binding-and-cardinality.md`
  - `adr/sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md`
- `adr/README.md`: index line for the amendment.
- `docs/mermaid/app-pending-registration-lifecycle.mmd` and
  `docs/mermaid/app-pending-registration-transition-inventory.md`: new, marked proposed.
- `docs/mermaid/README.md`: links to both files.
- `evidence/2026-11-14-front-channel-id-token-rp-FCHB.md`: corrected the database_consistency
  wording (below).

## Access requirements

The full table (purpose, claims, TTL, size per step) is in the amendment section "Requirements for
Access". In short:

- **H1 (Access sends).** After its own identifier proof. About 1,350 characters or fewer.
- **H2 (Access receives).** Start answer. About 1,100 characters.
- **H3 (Access sends).** Exactly one credential. About 1,370 characters for ES256 or 1,710 for RS256
  with a 64-byte ID. RS256 IDs above about 250 bytes do not fit (O-6).
- **H4 (Access receives).** Completion answer. About 1,100 characters. Access enters canonical Sign
  In only when `cer` and `reg` match.
- **H5 / H6.** Cancel and its answer. About 900 characters each.

Every handoff has a 120-second TTL and a single-use `jti`. In addition, Access must use a fresh
`jti` on every re-send, measure the URL before redirecting, create no session from H2, publish JWKS
per realm and follow the rotation rule, and keep sign-up at 503 until Governance is deployed.

## Owner items

Each has options and a recommendation in the ADR:

- **O-1 Registration lifetime.** Recommend 30 minutes.
- **O-2 Does a pending identifier block a second sign-up?** Recommend that a newer start with fresh
  proof supersedes it.
- **O-3 Retention before purge.** Recommend 7 days.
- **O-4 Requirement set per method.** Recommend keeping the accepted sets and moving the telephone
  passcode to after completion.
- **O-5 Status written at completion.** Recommend `ACTIVE`.
- **O-6 Oversized credential handoff.** Recommend refusing for now and measuring.

## Step 2: database_consistency wording

- `bundle exec database_consistency` (gem 3.1.2) ran against the same worktree and exited 0. The
  output's last lines were "No configuration files were provided" and nothing else, so no failing
  report was printed. Boot printed only framework load-hook and instrumentation notices.
- Gem source (`lib/database_consistency/configuration.rb`, `lib/database_consistency.rb`): with no
  file, `global_enabling` and `database_enabled?` both default to true, so every checker runs. The
  exit code is 1 when any report fails or an error was rescued.
- The FCHB table row now records a pass. The "missing DatabaseConsistency configuration" item was
  removed from its remaining risks. No configuration file was added.

## Checks and limits

- No Mermaid renderer is installed. The new diagram was checked only by reading; semicolons were
  removed from its transition labels because Mermaid can treat them as separators. The diagram has
  not been rendered.
- No tests were run, because no executable file changed.
- The new prose was checked for non-English text: none. It was checked for "sentry", "guardrail" and
  "checkpoint": they appear only in the vocabulary mapping and in references to existing ADR names.
- Pre-existing and untouched:
  - 16 dirty structure dumps (listed in FCHB). The working `db/app_zenith_structure.sql` is 18
    lines, so index facts were read from the committed version at HEAD.
  - The Bun format failure in `gait/features/sign_out/sign_out_confirmation.test.tsx`.

## Confirmation

No application code, test, route, migration, structure dump, job, configuration or
`config/credentials/*.yml.enc` file was changed (`git status -- config/credentials` is empty). No
`.env` content was read and no secret or environment value was printed. Only documentation and
evidence files changed.
