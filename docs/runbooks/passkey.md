# Passkey Records

## Scope and current state

Use this procedure for existing Base app and Base org passkey records and their audit events.
Authenticated inventory pages are read-only and show the credentials owned by the current Client or
Operator. This repository has no local passkey sign-in, browser verification or registration-start
route. Base App's RP entry hands off to Visa through Jump but does not run a passkey ceremony; Base
Org and Tech RP sign-in remain disconnected.

Stored credentials, models and migrations remain intact. Do not edit credential rows directly or
infer that a stored passkey provides a currently usable sign-in path.

## Inspect inventory

Use the Base app or Base org identity passkey pages with an existing authorized session. The index
lists the owner's stored credentials; a detail page shows the selected credential. Metadata such as
provider name, AAGUID, transports and backup state is descriptive only.

## Audit delivery

Base app and Base org registration outbox events use `passkey.registered.signup` or
`passkey.registered.settings`. Delivery scans pending events in bounded pages through the highest
pending ID observed for each source at the start of the scan. A failed event remains unacknowledged,
is reported, and is retried on a later run. Events added beyond the scan boundary wait for that
later run.

Delivery rejects metadata that replaces the source surface, passkey reference or actor reference.
The event remains unacknowledged for investigation while later events are attempted.

## Failure handling

- Preserve failed or unacknowledged events for investigation; do not acknowledge them manually.
- Use the event and operation references to inspect the owning Base path. Never copy credential
  material or signed tokens into logs, tickets or chat.
- Escalate a credential ownership or audit mismatch to the Base identity owner. The current local
  routes cannot start a replacement ceremony.
