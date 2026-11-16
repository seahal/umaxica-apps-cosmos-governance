# Jump handoff

Status: historical checklist; excluded from the active checklist index.

This checklist previously described the local Rails 0.4.0 return graph. The owner-approved local
surface hard reset removed the local issuers and destinations named by that graph. The current
`JumpRtReturnPolicy::EDGE_CATALOG` is empty, and a correctly signed return token cannot authorize a
local redirect. `JumpRtReturnVerification` remains on the owned Base and Tech controller boundaries
and rejects return-token requests that have no approved source edge.

The protocol history remains in the [directed Jump handoff decision](../../adr/jump-directed-rails-handoff-contract.md).
Current surface scope and verification are recorded in the
[local surface hard reset specification](../../specs/local-surface-hard-reset/spec.md).
