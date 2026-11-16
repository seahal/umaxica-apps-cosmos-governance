# Sign-up Finalization in Auth and Sign In First for Every Entry Method

## Status

**Accepted (2026-10-21, owner decisions D-69 U1–U6, D-105, D-128, D-131); written 2026-10-24 before
implementation (WU-05a); implemented 2026-10-24 (WU-05b … WU-05g and WU-06).**

**Split amendment proposed (2026-11-14), design only.** After the Cosmos split, Governance owns the
pending registration and its completion; Access owns the Auth ceremony. See
[Cosmos split amendment](#cosmos-split-amendment-governance-owned-pending-registration-2026-11-14).
It supersedes decisions 1, 3, 4, 5 and 8 below once the owner accepts it. Its owner items are open,
and no code or migration implements it. Sign-up stays closed (503 in Auth) until a later order
implements it.

## Context

APP email and telephone, and COM email and telephone, already create the pending principal in Auth
after a redeemed sign-up Admission. They finalize through the shared
`finalize_sign_up_from_checkpoint!` (Flow row lock, `SignUp::FinalizationPolicy`, principal writers,
`IdentityGraphProvisioner`, `SignUpStateMachine :finalize/:complete`). They then hand off to the
canonical Sign In flow.

APP Google and Apple do not. They have no pending principal in Auth, and the Base
`/social/authentication/completion` page commits the Client, External Identity and graph
(`IdentitySocialCeremonyFinalCommitter#commit_signup!`). It then issues the OIDC result directly
(`BaseAuthAdmissionCoordinator.register_result_and_issue!`) without the canonical Sign In policy.
That contradicts `adr/sign-in-first-and-sign-up-handoff.md`.

No ADR states that Auth may finalize a registration. The comment in `SignUpSocialBirthdateSupport`
and `adr/sign-up-authentication-handoff-and-social-rt.md` state the opposite for social sign-up.

## Decision

1. **Auth owns registration, never sessions.**
   - Auth may create pending principals and finalize sign-up through the shared operations on the
     principal writers.
   - It may not issue a Root or Browser Session, an OIDC code or a token. Root Session and OIDC
     authority stay with the authorization server (Base today, Visa after WU-02); RP Sessions stay
     with Base.
2. **One Finalization contract for the six paths:** APP email, telephone, Google and Apple; COM
   email and telephone. Google and Apple stay separate entry methods with their own requirements
   (`confirmation`, `birthdate`). They are never merged into one "social" method.
3. **Social pending Client (U1, P1–P5).**
   - It is created in Auth only:
     - under a redeemed Admission whose effective intent is sign-up (D-72);
     - after the provider evidence for that Admission's ceremony is verified;
     - after the confirmation POST passed the ceremony-bound Turnstile (`verify_for_ceremony`,
       action `social_signup_confirmation`).
   - It is one per Flow, recorded on the Flow under the Flow lock, in status
     `UNVERIFIED_WITH_SIGN_UP`.
   - It has no External Identity, contact or credential before Finalization.
   - It is never found by provider subject, email or browser.
4. **Candidate (U2, C1–C3).**
   - `IdentitySocialCeremonyCandidateStore` (PostgreSQL, OP database) holds only the verified
     provider principal.
   - `expires_at` is at most the attempt's curfew, the Flow lifetime and the provider-evidence
     lifetime.
   - Pages read it without consuming it. Finalization consumes it once, under the Flow lock.
   - An expired or mismatched Candidate is refused and never revived.
5. **Decisive commit (D-131) and deadline (D-105).**
   - Under the OP Flow/Binding lock, Finalization compares the Binding's `curfew_at` with the OP
     database clock (D-75).
   - At or after the deadline it fails closed: no authority, no session, no evidence.
   - Before the deadline, the principal database commits in one transaction:
     - the registered status (`VERIFIED_WITH_SIGN_UP` on APP, the same states on COM per D-128);
     - for social sign-up, the External Identity, after re-checking that `(issuer, subject)` is
       unregistered and not release-blocked under `ClientExternalIdentity.with_subject_lock`.
   - That commit decides "registered". After it, graph provisioning and OP Flow completion are
     completed idempotently later; they are never undone or deleted as compensation.
6. **Sign In First (U6, S1–S4).**
   - Every entry method ends in `handoff_to_sign_in_flow!` → canonical Sign In (eligibility,
     guardrail, checkpoint, MFA, selector, cooldown, session limit) → OIDC evidence → the
     authority's result receiver.
   - No sign-up path calls `register_result_and_issue!`.
   - A Sign In refusal after the decisive commit is a Sign In failure.
7. **Resume and re-registration (U5).**
   - Resuming an unfinished Flow requires authority over that Flow (its Admission and Ceremony), or
     a fresh provider authentication.
   - The same email or the same browser never grants ownership of a pending Client.
   - Completed identities, other people's Flows and other operations' data are never taken over.
8. **Removal (WU-05g).** The Base social completion keeps only the non-sign-up uses classified in
   two.md §5.H. Its sign-up branches, and `IdentitySocialCeremonyFinalCommitter#commit_signup!`, are
   removed after every caller is moved.

## Supersedes

- `adr/sign-up-authentication-handoff-and-social-rt.md`, where it places the social sign-up commit
  and its OIDC result at Base.
- The ownership statement in the `SignUpSocialBirthdateSupport` comment.

The checkpoint and Turnstile boundaries in `adr/sign-up-checkpoint-turnstile-boundary.md` and
`adr/turnstile-visible-placement-policy.md` are unchanged. The ceremony-bound social confirmation
Turnstile remains the documented stronger exception.

## Consequences

- A person who reaches Finalization seconds before the curfew may have to start again (D-105).
- A crash after the decisive commit leaves a registered principal with an unfinished Flow. The next
  access is an ordinary sign-in. (The hand-run `SignUpAttemptDiagnosisInventory` of WU-26 was
  withdrawn on 2026-10-26, D-196; the automatic stuck-registration report remains.)
- The social sign-up gains the Sign In screens (MFA, checkpoint) that email and telephone sign-up
  already show.

## Verification

- **2026-10-24 (WU-05a … g, WU-06):** implemented, including the D-105 curfew comparison at
  Finalization. See `evidence/2026-10-24-wu05abc-finalization-adr-intent-entry-flow-W5AC.md`,
  `evidence/2026-10-24-wu05dg-social-sign-up-in-auth-W5DG.md`, and the WU-06 evidence record.
- The end-to-end Google sign-up test reaches exactly one Root at Base through canonical Sign In, and
  that Root keeps the provider ceremony's event time.

## Cosmos split amendment: Governance-owned pending registration (2026-11-14)

### Status and scope

**Accepted (owner, 2026-11-15), design only.** Every owner item below was decided as recommended
(see "Owner decisions"). Written for
`plans/2026-11-14-pending-registration-lifecycle-design-work-order.md` before the Stage 4 handoff is
built. It takes effect when the owner accepts it and settles the owner items at the end of this
section. No route, model, migration or job implements it. Sign-up stays closed (503 in Auth) until a
later order implements both sides.

Scope is APP public sign-up (Client) for the email, telephone, Google and Apple entry methods. Org
has no public sign-up and is out of scope. Org operators keep their invitation path.

Fixed context, not reopened here:

- Access and Governance share no database, cookie or session. The browser carries every handoff as a
  signed PS256 JWS through Jump (`jump.umaxica.net`). The only server-side read between them is the
  peer's published JWKS (`/.well-known/jwks.json`, per realm). Access asks and fails closed without
  a valid answer.
- A Jump destination URL is at most 2,048 characters and `rt` at most 4,096. A PS256 signature alone
  is 512 characters. Handoffs carry credential IDs or one looked-up credential, never lists.
- RPs send no `prompt=create`. Sign-in and sign-up share one neutral entry.
- Operations on data are by the person themself only. Tokens carry actor and subject as separate
  claims and are refused when they differ, so that delegation can be added later.
- The old server-pushed revocation path is being removed.
- The existing Jump edges `auth-app-ww -> base-app-ww` and `base-app-ww -> auth-app-ww` carry every
  handoff below. No new edge is needed.

### Why this design

The previous implementation spread one registration across two databases (the OP Flow in
`op_base_app`, the principal in `app_zenith`) and several writers. It created a pending `Client`
(`UNVERIFIED_WITH_SIGN_UP`) and pending contact rows before the person had finished. It then needed
cross-database lock ordering, compensating cleanup, lost-commit recovery, curfew rechecks and
browser-attempt guards. Each was added after a defect was found. The evidence index is in
`evidence/2026-11-14-pending-registration-lifecycle-design-PRL4.md`.

This design therefore holds to five rules:

1. **One owner, one database, one commit.** Governance owns the pending registration. Every state
   change, its handoff `jti` receipt, and the account rows it creates commit in one `app_zenith`
   transaction on the database clock. No step needs a second database or a peer to commit together.
2. **No account rows before completion.** No `Client`, contact, external identity or passkey row
   exists for a registration until it completes. Abandonment therefore leaves only the registration
   row, never a half-made account.
3. **A pending claim never blocks the identifier's controller.** A newer start with fresh proof of
   the same identifier supersedes the older pending registration (owner item O-2).
4. **Terminal states are absorbing, and completed work is never repeated or undone.** Retries and
   late duplicates are classified as replay or conflict and answered from stored state.
5. **Both sides bind the browser independently.** Governance binds its own host-only cookie and
   Access binds its own ceremony. Each handoff carries the other side's reference, so neither side
   needs to see the other's cookie.

### Sign-flow terms

These four terms replace the earlier sentry, guardrail and checkpoint wording for sign-up and
sign-in. Lifecycle states and events keep the vocabulary of
[`idp-flow-lifecycle-vocabulary.md`](idp-flow-lifecycle-vocabulary.md).

| Term         | Meaning in this lifecycle                                                                                                                                                                                                                                                  | Owner                                                                                    |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| availability | Whether sign-up is open at all. While it is closed, Auth answers 503 and Governance refuses every registration handoff with `unavailable` and writes nothing.                                                                                                              | Access for the Auth entry; Governance for its receivers. Each side checks its own.       |
| ingress      | The checks a request passes before it may touch state: Turnstile and the neutral entry at Auth; PS256 signature, `iss`, `aud`, `typ`, `exp`, single-use `jti` and the browser bindings at Governance.                                                                      | The receiving side.                                                                      |
| eligibility  | Whether this person may register: the one-day minimum birthdate rule of [`sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md`](sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md), and the identifier not being bound to an active account. | Governance. Access may pre-check the birthdate format but never decides.                 |
| requirements | The items to clear before completion: proof of the identifier, birthdate, social confirmation, and the Auth credential the entry method requires.                                                                                                                          | Governance defines the set per entry method. Access runs the ceremonies that clear them. |

### Handoffs

All handoffs are compact PS256 JWS with an explicit `typ` header per kind, so a token of one kind is
never accepted as another. All have `exp - iat` of 120 seconds. All carry `jti`, which the receiver
consumes once. All carry `cer`, the SHA-256 of Access's ceremony reference (Access keeps the
reference itself in its own session). Governance-issued tokens are signed with the Base App key and
verified with Base JWKS. Access-issued tokens are signed with the Auth App key and verified with
Auth JWKS. Governance receivers are top-level GET navigations from Jump. They verify, commit, and
answer with a 303 to the next Jump URL, carrying `Cache-Control: no-store` and
`Referrer-Policy: no-referrer`, as the accepted front-channel ID Token callback does. Exact route
paths are left to the implementation order and `generic/routing.mdc`.

| ID  | Direction and `typ`                        | Purpose                                                                                                                                                                                                                    |
| --- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| H1  | Auth → Base, `registration-start+jwt`      | After Access has verified the identifier (email or telephone proof, or a verified Google/Apple identity) and collected the birthdate and, for social sign-up, the confirmation. Asks Governance to start the registration. |
| H2  | Base → Auth, `registration-answer+jwt`     | Answer to H1: `started` (reference, user handle, outstanding requirement, deadline), `completed`, or a refusal reason.                                                                                                     |
| H3  | Auth → Base, `registration-credential+jwt` | Delivers the one Auth credential that the outstanding requirement asks for.                                                                                                                                                |
| H4  | Base → Auth, `registration-answer+jwt`     | Answer to H3: `completed` (subject), or a refusal reason.                                                                                                                                                                  |
| H5  | Auth → Base, `registration-cancel+jwt`     | The person pressed Cancel in Auth while the registration was pending.                                                                                                                                                      |
| H6  | Base → Auth, `registration-answer+jwt`     | Answer to H5: `cancelled`, `completed` (cancel came too late), or `not_active`.                                                                                                                                            |

When a handoff cannot be verified at all (signature, `iss`, `aud`, `typ`, `exp` or malformed), or
when sign-up is unavailable, Governance answers with a fixed plain refusal page (400 or 503) and no
signed answer. Access then fails closed, as the fixed context requires.

Answer reasons are a closed set: `started`, `completed`, `cancelled`, `sign_in_instead`,
`ineligible`, `credential_rejected`, `conflict`, `not_active`, `unavailable`. A reason is never
derived from free text.

### Lifecycle

One Governance-owned axis: `ClientRegistration` in `app_zenith`, with one NOT NULL `status_id`
referencing an id-only status table. The diagram and transition inventory are
[`docs/mermaid/app-pending-registration-lifecycle.mmd`](../docs/mermaid/app-pending-registration-lifecycle.mmd)
and
[`docs/mermaid/app-pending-registration-transition-inventory.md`](../docs/mermaid/app-pending-registration-transition-inventory.md).

| State                | Kind                   | Meaning                                                                                                                                                                     |
| -------------------- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CREDENTIAL_PENDING` | in progress (only one) | Start accepted. Eligibility and every requirement except one Auth credential are cleared. The identifier claim and the user handle reservation are held.                    |
| `COMPLETED`          | terminal               | The account was created in the same transaction.                                                                                                                            |
| `CANCELLED`          | terminal               | The person cancelled through H5.                                                                                                                                            |
| `EXPIRED`            | terminal               | `deadline_at` passed on the database clock.                                                                                                                                 |
| `HALTED`             | terminal               | The system ended it. Reason codes (stored on the audit event, not the row): `superseded_by_identifier`, `superseded_in_browser`, `identifier_taken`, `integrity_violation`. |

Events follow the vocabulary ADR: `start`, `complete`, `cancel`, `expire`, `halt`. The lifecycle has
no `back` edge and no `FAILED` state. A rejected credential or a refused request is a `rejected`,
`conflict` or `replay` outcome with the lifecycle unchanged. One named transition writer owns every
edge. It locks and reloads the row and rechecks the source state and deadline on the `app_zenith`
clock. It writes the audit outbox row in the same transaction. Callers never write `status_id`.

When the entry method's requirement set has no Auth credential (email, Google and Apple under the
accepted requirement sets), H1 runs `start` and `complete` in one transaction. The registration
never rests in `CREDENTIAL_PENDING`. Telephone (passkey required) is therefore the only accepted
method that rests in the pending state. This is the path where earlier abandoned registrations
blocked the number.

### Start (H1)

1. **Ingress.** Verify the JWS, then insert the `jti` receipt; a duplicate is `replay` (see below).
   Refuse when H1 carries `sub` or `act`: no subject exists before completion.
2. **Eligibility.** Recompute the birthdate rule on the Governance date boundary. Check whether the
   identifier (email address digest, telephone number digest, or provider `(issuer, subject)`
   digest) is bound to an active account.
   - Active: answer `sign_in_instead` and create nothing. This answer reveals existence only to a
     browser that has just proved control of the identifier.
   - Ineligible birthdate: answer `ineligible` and create nothing.
3. **Supersede, in the same transaction.** Lock any `CREDENTIAL_PENDING` registration holding the
   same identifier claim, or bound to the same Governance browser cookie, and `halt` it
   (`superseded_by_identifier` or `superseded_in_browser`). Supersession never touches a terminal
   registration.
4. **Create.** Insert the registration in `CREDENTIAL_PENDING` with:
   - the identifier digest and the encrypted identifier;
   - the birthdate and the entry method;
   - a fresh 32-byte WebAuthn user handle;
   - `cer`;
   - the SHA-256 of a fresh 32-byte browser secret;
   - `deadline_at` = database now + the registration lifetime (owner item O-1).

   Set the secret in a `__Host-` cookie: Secure, HttpOnly, `SameSite=Lax` (it must arrive on the
   top-level GET from Jump), and expiring at `deadline_at`. When the method needs no Auth
   credential, `complete` in the same transaction (see Completion).

5. **Answer** H2 `started` with the registration public ID, user handle, outstanding requirement and
   deadline. When the start also completed, answer `completed`.

Two concurrent H1s for the same identifier with no existing claim race on the partial unique index.
The loser rolls back and is answered `conflict`. It is not retried automatically.

**Why the browser is bound on both sides.** A captured, unused H1 navigated in a victim's browser
creates a registration bound to the victim's Governance cookie. But Access refuses the H2 answer,
because the victim's Auth session does not own that `cer`. The victim therefore never reaches
credential registration on the attacker's identifier. The remaining effect is a pending row that
expires, and possibly the supersession of the victim's own pending registration in that browser.
Governance limits H1 creations per identifier digest and per client address to bound that nuisance.

### Credential registration and completion (H3)

Access runs the WebAuthn registration ceremony with the user handle from H2. It delivers exactly one
credential in H3. Governance commits in one `app_zenith` transaction on the database clock:

1. Insert the `jti` receipt (replay barrier).
2. Lock and reload the registration. Require all of:
   - `CREDENTIAL_PENDING`;
   - `deadline_at` in the future (otherwise `expire` it, commit, and answer `not_active`);
   - the cookie secret digest and `cer` matching the stored values (otherwise `conflict`, nothing
     written beyond the receipt);
   - the H3 method and registration reference agreeing with the row.
3. Create the account rows through their owning writers: `Client` (status per owner item O-5, the
   reserved user handle and the birthdate), the effective `ClientEmail` or `ClientTelephone` binding
   or the `ClientExternalIdentity`, the `ClientPasskey`, and one `ClientRegistrationCompletion`
   receipt whose `sign_up_flow_ref` is the registration public ID. Write the Chronicle audit outbox
   rows.
4. `complete` the registration.

Outcomes when a unique index refuses the commit:

- **Identifier index.** The commit rolls back. A second transaction stores the receipt and `halt`s
  the registration as `identifier_taken`; the answer is `sign_in_instead`.
- **Credential index.** The commit rolls back. A second transaction stores the receipt and writes a
  rejected event; the registration stays `CREDENTIAL_PENDING` and the answer is
  `credential_rejected`. The person may try another authenticator before the deadline.

After the commit, work owned by other databases (for example identity-graph provisioning or Avatar
setup) runs idempotently, keyed by the completion receipt. It is retried, never compensated. The
answer H4 `completed` carries `sub` and `act` equal to the new Client public ID. Access then enters
canonical Sign In ([`sign-in-first-and-sign-up-handoff.md`](sign-in-first-and-sign-up-handoff.md)).
Completion is not a session grant. A later Sign In or RP callback failure never deletes the account.

### Cancellation (H5)

Cancel is the person's explicit action in Auth. Access sends H5 and then returns `access_denied` to
the RP as it does today. Governance verifies H5, requires the cookie and `cer` to match, and
`cancel`s a `CREDENTIAL_PENDING` registration, which releases the claim at once. On a `COMPLETED`
registration, cancel is refused with `completed`: the account stays, and the person is told they can
sign in. On other terminal states the answer is `not_active`. Cancel is idempotent. When H5 never
arrives (Jump failure, closed tab), supersession or expiry releases the claim instead. Cancel
performs no physical deletion.

### Expiry and cleanup

- **Request-time expiry is authoritative.** Every receiver compares `deadline_at` with the
  `app_zenith` clock under the row lock before any other transition.
- **Sweep.** A recurring `ClientRegistrationExpiryJob` runs every five minutes. It selects
  `CREDENTIAL_PENDING` rows past `deadline_at` in batches, using `FOR UPDATE SKIP LOCKED`, and
  `expire`s each through the transition writer. Each row's audit outbox row is written in the same
  transaction. Terminal rows are skipped, so the job is idempotent. A deadlock re-raises for Active
  Job retry, and any other per-row error is recorded without stopping the batch.
- **Purge.** Every row has NOT NULL `purge_after`: set at creation to `deadline_at` plus the
  retention period, and reset at each terminal transition to the terminal time plus the retention
  period (owner item O-3). A separate `ClientRegistrationPurgeJob` physically deletes terminal rows,
  and receipts whose `exp` has passed, once `purge_after` is reached. It never selects
  `CREDENTIAL_PENDING`, and it is idempotent.
- **Audit.** Each `start`, `complete`, `cancel`, `expire` and `halt` writes one Chronicle event
  through the same-transaction outbox, with the registration public ID, method, outcome and reason
  code. The event never includes the identifier, the birthdate, credential material, tokens or
  cookies. Refusals that consume a `jti` also write an event. Audit records survive the purge.

### Interruptions

| Interruption                             | Behavior                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Back to a consumed handoff URL           | `replay`. No side effect. When the cookie binds the registration, Governance re-issues the answer for the current state with a new `jti`: H2 `started` while pending, `completed` when completed. Otherwise it shows the generic page.                                                                                                                                                                                   |
| Back inside Auth pages                   | Access's concern. Anything Access re-sends is a new handoff with a new `jti`.                                                                                                                                                                                                                                                                                                                                            |
| Second tab, same browser                 | A new H1 supersedes the browser's pending registration (`superseded_in_browser`), or the identifier's (`superseded_by_identifier`). The old tab's H3 or H5 gets `conflict` or `not_active`. This matches Access's one Auth ceremony per browser.                                                                                                                                                                         |
| Closed tab                               | The registration stays pending until the deadline, then expires. A newer verified start releases the identifier earlier.                                                                                                                                                                                                                                                                                                 |
| Jump failure, Auth → Base                | Governance writes nothing. The token expires in 120 seconds. Access re-sends with a new `jti`.                                                                                                                                                                                                                                                                                                                           |
| Jump failure, Base → Auth after a commit | Governance state is already committed. A re-sent H3 for a completed registration returns `completed` with the same subject and repeats no work. A re-sent H1 supersedes a pending registration (nothing durable is lost) or gets `sign_in_instead` when the account exists. A passkey already created on the authenticator for a superseded user handle is left orphaned on the device; Access may signal it as unknown. |
| Access session expiry                    | Access refuses H2, H4 or H6 for an unknown `cer`. Governance state is unchanged. A restart supersedes a pending registration or gets `sign_in_instead`. A completed account is kept.                                                                                                                                                                                                                                     |
| Governance side expiry                   | Governance holds no session during sign-up. A missing or expired registration cookie is `conflict`, and the person restarts. After completion, an expired RP pending flow fails at the RP callback as an ordinary Sign In failure. The account is kept.                                                                                                                                                                  |
| Key rotation                             | A receiver that sees an unknown `kid` refreshes the peer JWKS once, with a rate limit, then refuses with state unchanged. Signers publish a new key at least one JWKS cache lifetime before first use. They keep the old key published for at least the handoff TTL plus the cache lifetime after its last use.                                                                                                          |
| Late duplicate                           | A known `jti` is `replay`. A new `jti` for a terminal registration gets `completed` (completed, bound browser only) or `not_active`, and writes nothing.                                                                                                                                                                                                                                                                 |

### What the "already done" page may reveal

| Situation                                 | May show                                                                 | Never shows                                                        |
| ----------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| Completed, and the cookie and `cer` match | The account was created; continue to sign in (re-issued H4)              | —                                                                  |
| Completed, binding does not match         | Generic: "This sign-up link is no longer valid. Start again or sign in." | Whether an account exists, the identifier, the subject, timestamps |
| Cancelled, expired or halted              | The same generic text                                                    | The reason code, the identifier, whether a newer attempt exists    |
| H1 for an identifier already active       | Through Access: an account already uses this identifier; sign in         | The account's other identifiers or credentials                     |

### Storage target (for the implementation order; no migration here)

- `client_registrations` (`app_zenith`), all NOT NULL: `public_id`, `status_id`, `method_id`
  (reusing `ClientRegistrationCompletionMethod`), `identifier_digest`, encrypted identifier,
  `birthdate`, `webauthn_user_handle` (unique), `access_ceremony_digest`, `browser_secret_digest`,
  `deadline_at`, `status_changed_at`, `purge_after`. Partial unique indexes cover
  `(method_id, identifier_digest)` and `browser_secret_digest` where `status_id` is
  `CREDENTIAL_PENDING`. No column is NULL to mean "not yet". The completed account is reached
  through `ClientRegistrationCompletion.sign_up_flow_ref`, not a nullable `client_id`.
- `client_registration_statuses`: id-only reference rows for the five states.
- A handoff receipt table keyed by unique `jti`, recording the handoff kind and `exp`. The exact
  columns follow the NULL rule in the implementation order.
- The existing contact tables encode binding state with nullable `binding_finalized_at` and
  `binding_released_at` timestamps. This is an existing violation of the NULL rule; this design
  writes them only through their existing writers and does not extend the pattern.

### Requirements for Access

Each item is a requirement on Access. It describes only what crosses the boundary, not Access
internals. Size estimates assume a protected header of about 115 characters and a 512-character
signature (overhead about 630 characters). They also assume a destination prefix of about 50
characters, which leaves about 1,370 Base64url characters (about 1,000 bytes of JSON) for claims.

| Step | Access sends or receives                                                                                                   | Claims                                                                                                                                                              | TTL   | Size estimate                                                                                                                                              |
| ---- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| H1   | Sends, after its own identifier proof, birthdate and (social) confirmation                                                 | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, `mth`, identifier (email ≤ 254, E.164 ≤ 16, or provider `iss` + `sub` ≤ 255), proof time, `bdt`, social confirmation flag | 120 s | ≤ 1,350 characters with a 254-character email                                                                                                              |
| H2   | Receives; consumes `jti` once; requires its own `cer`                                                                      | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, reason, `reg` (21), user handle (43), outstanding requirement, `dl`                                                       | 120 s | about 1,100 characters                                                                                                                                     |
| H3   | Sends exactly one credential for `reg` from H2 of the same ceremony                                                        | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, `reg`, `mth`, credential ID, COSE public key, `alg`, sign count, UV/BE/BS flags, transports, AAGUID                       | 120 s | ES256 with a 64-byte ID: about 1,370 characters. RS256 with a 64-byte ID: about 1,710. IDs above about 250 bytes with RS256 exceed 2,048 (owner item O-6). |
| H4   | Receives; enters canonical Sign In only when `cer` and `reg` match its live ceremony and the credential it just registered | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, reason, `reg`, `sub`, `act` (both the Client public ID), completion receipt ID, `mth`                                     | 120 s | about 1,100 characters                                                                                                                                     |
| H5   | Sends when the person cancels during `CREDENTIAL_PENDING`                                                                  | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, `reg`                                                                                                                     | 120 s | about 900 characters                                                                                                                                       |
| H6   | Receives                                                                                                                   | `iss`, `aud`, `iat`, `exp`, `jti`, `cer`, reason, `reg`                                                                                                             | 120 s | about 900 characters                                                                                                                                       |

Access must also:

- Publish its JWKS per realm, and follow the key rotation rule above.
- Use a fresh `jti` for every re-send. Never re-send a consumed token.
- Measure the full destination URL before redirecting. Above 2,048 characters, refuse with an
  explicit error and keep the ceremony at the credential step; never truncate a claim.
- Never create an OP session, token or ID Token from H2.
- Treat H4 as permission to start Sign In, not as Sign In.
- Keep Auth's sign-up entry at 503 until Governance's receivers are deployed and enabled.

### Supersession map

| Earlier decision                                                                                                                                                                                                         | Status after acceptance                                                                                                                                                                                                                                        |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| This ADR, decisions 1, 3, 4, 5 and 8 (Auth creates pending principals and finalizes; social pending Client; Candidate store; decisive commit in the principal database under an OP lock; Base social completion removal) | Superseded: Governance creates and completes; no pending Client exists; the decisive commit is the single `app_zenith` completion transaction.                                                                                                                 |
| This ADR, decisions 2, 6 and 7 (one Finalization contract for the entry methods; Sign In First; resume needs authority)                                                                                                  | Kept. Resume becomes supersession by fresh proof.                                                                                                                                                                                                              |
| [`sign-in-first-and-sign-up-handoff.md`](sign-in-first-and-sign-up-handoff.md)                                                                                                                                           | Kept. Its "guardrail, checkpoint" wording reads as eligibility and requirements.                                                                                                                                                                               |
| [`sign-up-authentication-handoff-and-social-rt.md`](sign-up-authentication-handoff-and-social-rt.md)                                                                                                                     | Its pending telephone release, cleanup ownership and the Sign Up versus Sign In failure domains are restated here. Its in-request finalization-to-Sign-In handoff is replaced by H4.                                                                           |
| [`sign-up-checkpoint-turnstile-boundary.md`](sign-up-checkpoint-turnstile-boundary.md)                                                                                                                                   | The checkpoint routes are Access's. The Turnstile placement at ingress is Access's. The rule that later steps need valid sequence authority is kept as Governance ingress (signature, `jti`, cookie, `cer`).                                                   |
| [`sign-up-cycle-cancellation-retention.md`](sign-up-cycle-cancellation-retention.md)                                                                                                                                     | Its flow states and `SignUpExpiryJob` are historical. Its principles are kept: cancel is idempotent and performs no physical deletion, expiry is request-time authoritative with a sweep, and purge is separate.                                               |
| [`sign-up-flow-admission-binding-and-cardinality.md`](sign-up-flow-admission-binding-and-cardinality.md)                                                                                                                 | Admission, Binding and Flow storage are Access's. Its D14 item (distributed cancel, switch, supersession and late results) is answered for registration by this section. One in-progress registration per identifier and per browser replaces one per Binding. |
| [`sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md`](sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md)                                                                                 | Kept. Governance evaluates the rule at H1.                                                                                                                                                                                                                     |

### Owner items

| ID  | Question                                                           | Options                                                                                                            | Recommendation                                                                                                                                                                                                                                  |
| --- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| O-1 | Registration lifetime (`deadline_at`)                              | 15, 30 or 60 minutes                                                                                               | 30 minutes. Identifier proof happens before H1, so the lifetime covers only the credential step. It matches the earlier 30-minute workflow target.                                                                                              |
| O-2 | Does a pending identifier block a second sign-up?                  | (a) block until expiry; (b) a newer start with fresh proof supersedes; (c) parallel pending, first completion wins | (b). Only someone who controls the identifier can supersede. Abandoned attempts never block. One pending claim keeps completion simple.                                                                                                         |
| O-3 | Retention of terminal registration rows before purge               | 0, 7 or 30 days                                                                                                    | 7 days. The rows hold an encrypted identifier and a birthdate. Audit events are kept separately, so a longer retention adds exposure without adding history.                                                                                    |
| O-4 | Requirement set after the split, especially the telephone passcode | keep every accepted item; or move the passcode after completion                                                    | Keep the accepted sets (email: birthdate; telephone: birthdate + passkey; Google/Apple: confirmation + birthdate). Move the telephone passcode to a Governance step after completion, because a secret must not travel through Access or a URL. |
| O-5 | Client status written at completion                                | `ACTIVE`; or `VERIFIED_WITH_SIGN_UP` as before                                                                     | `ACTIVE`. The pending state now lives in the registration row. `VERIFIED_WITH_SIGN_UP` was never moved on, which forced readers to accept two "active" values. Existing rows keep their value; retiring it needs a separate data decision.      |
| O-6 | Credential handoff above 2,048 characters                          | refuse with an explicit error; or add a POST transport for H3 only                                                 | Refuse now. Measure real authenticators in Access acceptance. Revisit only with measured evidence.                                                                                                                                              |

### Owner decisions (2026-11-15)

The owner accepted every recommendation above:

- O-1: registration lifetime is 30 minutes.
- O-2: a newer start with fresh identifier proof supersedes the pending registration.
- O-3: terminal registration rows are purged after 7 days.
- O-4: keep the accepted requirement sets; the telephone passcode moves to a Governance step after
  completion.
- O-5: completion writes `ACTIVE`.
- O-6: a credential handoff above 2,048 characters is refused with an explicit error; real
  authenticators are measured in Access acceptance before this is revisited.
