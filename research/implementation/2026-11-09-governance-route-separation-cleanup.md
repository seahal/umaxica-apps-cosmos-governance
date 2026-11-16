# Governance route separation cleanup implementation note

## Scope

This follow-up removes tests that exercise only routes owned by surfaces no longer drawn by this app, and keeps Governance coverage on Base/Tech entry points. It does not change application route or authorization behavior. The Access database-backed authentication path remains in place for its later local-cell work unit.

## Decisions

- Deleted the Warp-only Browser RP parent-state test. Retained tests that exercise Governance from Base/Tech while removing their Core/Auth/Visa/Warp/Palm/Edit host cases.
- Retargeted the shared Browser RP concern test to the Base app client, since Base app and Base org/Tech org use that concern. Its local-session failures remain associated with the next Base App local-cell work unit.
- Kept boundary checks whose subject is Governance behavior, even where they include an outside origin as a negative control (for example PWA route isolation and preference CSRF origin rejection).
- Retargeted retired-route, health, root canonicalization, and public resource route inventories to Base/Tech. Removed Auth/Visa-only cases.
- Preserved security-suite failures that were already listed in the pre-work baseline.

## Verification

See `evidence/2026-11-09-governance-route-separation-cleanup-M6H2.md` for the exact HEAD, full-suite comparison, grouped exception/frame inventory, and commands. The full test run produced no new errors. The security suite still has three baseline failures; fixing them would violate the instruction not to touch baseline failures.
