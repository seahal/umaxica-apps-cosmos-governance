# Governance: Explicit Replica Reads Only (2026-11-11)

Owner: Governance. Status: decided (owner), queued.

## Problem (observed 2026-11-11)

`config/initializers/multi_db.rb` enables Rails automatic role switching (`database_selector` with a
10-second delay and the session resolver). GET and HEAD requests read from a replica unless the same
browser session wrote within the delay. A change written by someone else (an operator disabling an
account, a revoked credential) is not covered, so a decision read on a GET can see a lagging replica.
Increasing the delay does not fix this.

## Decision (owner, 2026-11-11)

Remove automatic switching. Reads that may be slightly stale (for example admin lists) opt in to the
replica explicitly with `connected_to(role: :reading)`; everything else, and always the account-state,
credential and permission answers Governance gives Access, reads from the primary.

## Work order (Codex)

```
Remove database_selector, database_resolver and database_resolver_context from
config/initializers/multi_db.rb. Find reads that are safe to serve from a replica (lists and
reports with no authentication, authorization, account-state or credential decision) and wrap only
those in connected_to(role: :reading); report each one. Ensure the Access-facing lookup and
permission endpoints read from the primary. Run the affected tests and bin/rubocop. No commit.
```
