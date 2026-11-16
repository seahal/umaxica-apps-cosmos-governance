# Cookie Domain Scope

Credential cookies are host-only transport. They do not have a `Domain` attribute. Secure contexts
use the `__Host-` prefix and `Path=/`.

| Role                         | Secure context        | Insecure development/test |
| ---------------------------- | --------------------- | ------------------------- |
| Base root access             | `__Host-auth_access`  | `auth_access`             |
| Base root refresh            | `__Host-auth_refresh` | `auth_refresh`            |
| Base RP access               | `__Host-rp-access`    | `rp-access`               |
| Base RP refresh              | `__Host-rp-refresh`   | `rp-refresh`              |
| Base RP local session handle | `__Host-rp-session`   | `rp-session`              |

The `auth` cookie prefix names the root credential role; it does not identify a local Auth surface.
Base app and org RP cookies remain independent. Base App installs its RP cookies after the verified
callback commits the local session. Its sign-out clears those cookies after local revocation; only
the matching Refresh Token may be sent to Visa's revocation endpoint. Ordinary browser navigation
does not refresh OIDC credentials.

Preference transport has a separate contract. Its signed preference cookie is not an authentication
credential. The host-only preference binding proves browser ownership for bounded consent and Web
Push reads and writes. Preference domain scope remains realm-specific.

No cookie may carry a session identifier, access token, refresh token, DBSC value, authorization
grant, ceremony secret, one-time token, or raw credential in a JavaScript-readable mirror. Request
context such as `ri` remains in the URL.

## Related

- [Base and Tech surface boundary](../architecture/base-auth-seven-rp-boundary.md)
- [Preference behavior](../architecture/preference-behavior-contract.md)
- [Cookie naming decision](../../adr/cookie-domain-scope-by-surface.md)
