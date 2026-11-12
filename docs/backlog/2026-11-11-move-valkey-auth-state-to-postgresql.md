# Governance: Remove OP-Side Valkey State and Move the Rest Off Lua (2026-11-11)

Owner: Governance. Status: decided (owner), deferred; do it later. Access has its own backlog with the
same date and name.

## Decision (owner, 2026-11-11)

Security decisions do not live in Valkey or Lua; atomicity is not traded for performance
(`docs/backlog/2026-11-10-access-postgres-first-state-storage.md` in Access states the rule). Most of
Governance's Valkey use is left over from the single repository: it belongs to the OpenID Provider,
which is now Access, or to social sign-in, which moves to Access
(`adr/access-is-a-pure-openid-provider.md` in Access). Those parts are deleted, not moved.

## A. Security decisions held in Valkey (observed 2026-11-11)

| Decision | Code | Mechanism | Action |
| --- | --- | --- | --- |
| Authorization code single use | `app/services/valkey/auth_state/authorization_code_store.rb` | Lua | delete (Governance is an RP, not an OP) |
| Base <-> Auth opaque admission codes | `app/services/valkey/auth_state/opaque_admission_store.rb` | Lua CAS | delete with the Base <-> Auth handoff once Base signs in through OIDC; move to PostgreSQL only if a flow still needs it |
| OTP verification failure budgets | `app/models/email_otp_verification_failure_budget.rb`, `app/models/telephone_otp_verification_failure_budget.rb` | Lua `INCR` | delete (one-time codes run in Access ceremonies) |
| Base step-up marker | `app/adapters/base_step_up_marker_adapter.rb` | Valkey (`admission` namespace) | replace with the per-tab flow handle in PostgreSQL (`adr/browser-flow-handle-per-tab.md`) |
| Sign-out notices | `app/services/valkey/auth_state/sign_out_notice_store.rb` | Valkey | delete if no longer needed, else move |

## B. Rate limits: keep in Valkey, with conditions

Same rule as Access: Valkey only for short per-request bursts, failing closed when unavailable;
account-level limits and lockouts in PostgreSQL.

## C. Other

- `app/adapters/oidc_jwks_refetch_limiter.rb`: a Lua `SET NX` lease limiting how often the OP JWKS is
  refetched; falls back to a process-local window when Valkey is unavailable. Not a security decision.
  Simplify to the process-local window and drop the Lua, or keep without Lua.
- Social sign-in JWKS caches, if present, go with social sign-in (moves to Access).
- Coverband on the diagnostic Valkey: keep.
- RP refresh coordination namespace (`auth_state:rp_refresh` in `lib/umaxica/valkey/namespaces.rb`):
  check for users; delete if none.

## Work order (Codex, later; after the OP-only and social sign-in removal)

```
Remove OP-side and social sign-in Valkey state from Governance as listed in
docs/backlog/2026-11-11-move-valkey-auth-state-to-postgresql.md. Delete the authorization code store,
OTP failure budgets and (once Base signs in through OIDC) the opaque admission store; replace the Base
step-up marker with the per-tab flow handle; decide the JWKS refetch limiter per section C. Verify
account-level limits live in PostgreSQL. Remove Lua scripts and unused Valkey namespaces. No
compatibility layer; no commit. Record evidence/.
```
