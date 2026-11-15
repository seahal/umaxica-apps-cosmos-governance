# DB Write Allowlist

## Purpose

Normal `GET` and `HEAD` requests should be read-only unless the write is an explicit lifecycle
exception. This allowlist records the current accepted exceptions so future CI can fail any
unreviewed `INSERT`, `UPDATE`, or `DELETE` observed during read-only request tests.

The database remains the source of truth. JWTs are projections or runtime credentials, not an
authority to invent new state.

## Current Allowlist

| ID  | Classification               | Request phase               | Expected write                                                                                                                       | GET/HEAD lifecycle exception? | Current scope                                         |
| --- | ---------------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------- | ----------------------------------------------------- |
| W8  | Preference explicit update   | Preference write endpoint   | Persist an intentional preference update from PATCH/PUT/DELETE/POST.                                                                 | No                            | non-GET preference endpoints                          |
| W9  | Preference reset/rebootstrap | Preference reset endpoint   | Retire or replace the current shared preference and rebootstrap a fresh preference.                                                  | No                            | explicit reset/delete endpoint                        |
| W10 | Cookie consent write         | Web/API preference endpoint | Persist cookie-consent flags and receipt, then issue the committed Preference snapshot.                                              | No                            | Base app/org/com API and preference cookie screens    |
| W11 | Theme write                  | Web/API preference endpoint | Persist the submitted theme and issue the committed Preference snapshot.                                                             | No                            | Base app/org/com preference endpoints                 |
| W18 | Maintenance or repair task   | Explicit operator task      | Repair, admin, or maintenance writes performed outside ordinary read-only request handling.                                          | No                            | explicitly invoked tasks only                         |
| W19 | Base App RP callback         | `GET /oidc/callback`        | Commit verified identity and `sid` bindings and the RP session in `rp_base_app`; retire an expired same-`sid` session when required. | Yes                           | successful Base App callback after token verification |
| W20 | Base App RP sign-out         | `POST /sign/out`            | Revoke the current `rp_base_app` session before clearing RP credentials and leaving through Jump.                                    | No                            | authenticated Base App RP sign-out                    |
| W21 | Base App Back-Channel Logout | `POST /oidc/closures`       | Commit the `sid` tombstone, matching RP-session revocations and replay receipt in one `rp_base_app` transaction.                     | No                            | verified Visa Logout Token only                       |
| W22 | Base Org RP callback         | `GET /oidc/callback`        | Commit verified identity and `sid` bindings and the RP session in `rp_base_org`; retire an expired same-`sid` session when required. | Yes                           | successful Base Org callback after token verification |
| W23 | Base Org RP sign-out         | `POST /sign/out`            | Revoke the current `rp_base_org` session before clearing RP credentials and leaving through Jump.                                    | No                            | authenticated Base Org RP sign-out                    |
| W24 | Base Org Back-Channel Logout | `POST /oidc/closures`       | Commit the `sid` tombstone, matching RP-session revocations and replay receipt in one `rp_base_org` transaction.                     | No                            | verified Visa Org Logout Token only                   |

The former W1-W7 preference GET writes and W14-W15 authentication GET writes were removed from the
allowlist on 2026-09-25 after checking the current request lifecycle. `set_preferences_cookie`
returns through read-only preference loading for `GET`/`HEAD`, and browser request handling has no
session-activity tracking writer. Preference transport records are changed only at their explicit
write endpoints. Base App and Base Org own these RP write boundaries; neither hosts Visa
authorization or credential ceremonies. Callback writes occur only after state, issuer, token
exchange, and ID-token verification succeed. Org RP writes are isolated to `rp_base_org`.

W12 and W13, the former App/Org/Com login-time preference adoption writes, were retired on
2026-10-31. Provider login-time Preference adoption and logout rebuild paths were retired with the
provider routes. Base app/com/org continue to own their same-surface Preference reads and explicit
writes.

## CI Direction

Future CI should subscribe to SQL and fail `GET`/`HEAD` request tests when `INSERT`, `UPDATE`, or
`DELETE` appears outside this allowlist. A new write path must update this document before the test
allowlist expands.

The allowlist is intentionally behavioral. It does not grant permission to move writes into generic
controller setup, to repair broken JWTs from the database on normal reads, or to introduce hidden
state changes behind read-only routes.
