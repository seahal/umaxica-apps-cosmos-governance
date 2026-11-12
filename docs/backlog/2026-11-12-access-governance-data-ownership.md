# Access and Governance: Data Ownership and Exchanges (2026-11-12)

Owner: Governance with Access. Status: decided direction (owner); API contracts and service
authentication open (`research/2026-11-12-access-governance-service-communication-options.md`).
The decision is recorded in Access's `adr/access-is-a-pure-openid-provider.md`, decisions 17 to 19.

- Access owns OpenID Provider data only: OP sessions, authorization codes, PAR requests, refresh
  token families, DBSC bindings, consents and grants to relying parties (including MCP clients),
  client registrations, OP audit records.
- Governance owns everything else: accounts and `sub`, email addresses, telephone numbers,
  credential records (signed by Access), account state, profiles, avatars, preferences,
  organizations, memberships, roles.

Exchanges (one signed-request shape, public HTTPS):

| Exchange | Direction | Purpose |
| --- | --- | --- |
| Lookup | Access -> Governance | credential records and current permission during a ceremony |
| Registration | Access -> Governance | store a credential record signed by Access after a ceremony |
| OP data query | Governance -> Access | read OP data Governance shows or manages (sessions, connected clients) |
| Revocation command | Governance -> Access | end sessions, refresh tokens or grants; success only on Access's signed acknowledgement |

Credential changes: Governance redirects the browser to an Access ceremony; Access verifies, signs
and registers the record in Governance. Governance never writes a credential by itself; to remove
one it marks its record revoked and, if sessions must end at once, sends a revocation command.

Governance work this implies: screens for credentials, signed-in sessions and connected clients
(including MCP grants), backed by the lookup/registration endpoints it serves and the OP data
query and revocation commands it calls on Access.
