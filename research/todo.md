# Implementation pause notes

> **Scope update (2026-11-13):** Governance no longer runs authentication ceremonies. The former
> Auth ceremony migration item below is retired for this repository; Access owns those ceremonies.

- P1–P9 phase commits are on `feature` with per-phase pushes.
- See `evidence/2026-09-13-auth-boundary-consolidation.md` for executed checks and remaining gaps.
- Highest-priority follow-ups:
  1. Cut OIDC authorization-code exchange over to Valkey AuthorizationCodeStore and retire
     PostgreSQL AuthorizationCode tables/models.
  2. Retire deprecated shared browser clients after seven RP flows are fully wired.
  3. Run full Rails suite + SimpleCov and browser history tests; refresh evidence.
