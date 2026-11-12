# Durable acceptance checklists

`docs/checklists/` states WHAT MUST KEEP WORKING. `test/`, `gait/` and `e2e/` implement checks;
`evidence/` records WHAT WAS ACTUALLY OBSERVED. A checklist is neither a test result nor proof.

- [Session management](session-management.md)
- [Authorization](authorization.md)
- [Avatar ownership](avatar-ownership.md)
- [Contact identifiers](contact-identifiers.md)
- [Email observability](email-observability.md)
- [Identifier contracts](identifier-contracts.md)
- [Integrated stack](integrated-stack.md)
- [Preference lifecycle](preference-lifecycle.md)

Use one document per functional area, stable local IDs and explicit surface applicability. Link to
the accepted contract instead of copying implementation details. Use ordinary behavior statements,
not permanent checked boxes. Select lasting criteria from verified specs; one-time migration steps
and temporary acceptance stay with the change. Retired Auth/Visa browser flows have no checklist.

Read the relevant checklist before changing behavior. Update an intentionally changed contract in
the same change, with its authorizing spec or ADR. Surface disagreements with code, specs or ADRs;
never silently choose one. The initial entries extract existing accepted requirements, not a new
claim that the current implementation has passed them. Do not duplicate broader QA scenario lists;
link those where needed.
