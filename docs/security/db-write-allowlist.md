# DB Write Allowlist

## Purpose

Normal `GET` and `HEAD` requests should be read-only unless the write is an explicit lifecycle
exception. This allowlist records the current accepted exceptions so future CI can fail any
unreviewed `INSERT`, `UPDATE`, or `DELETE` observed during read-only request tests.

The database remains the source of truth. JWTs are projections or runtime credentials, not an
authority to invent new state.

## Current Allowlist

| ID  | Classification               | Request phase               | Expected write                                                                              | GET/HEAD lifecycle exception? | Current scope                                      |
| --- | ---------------------------- | --------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------- | -------------------------------------------------- |
| W8  | Preference explicit update   | Preference write endpoint   | Persist an intentional preference update from PATCH/PUT/DELETE/POST.                        | No                            | non-GET preference endpoints                       |
| W9  | Preference reset/rebootstrap | Preference reset endpoint   | Retire or replace the current shared preference and rebootstrap a fresh preference.         | No                            | explicit reset/delete endpoint                     |
| W10 | Cookie consent write         | Web/API preference endpoint | Persist cookie-consent flags and receipt, then issue the committed Preference snapshot.     | No                            | Base app/org/com API and preference cookie screens |
| W11 | Theme write                  | Web/API preference endpoint | Persist the submitted theme and issue the committed Preference snapshot.                    | No                            | Base app/org/com preference endpoints              |
| W18 | Maintenance or repair task   | Explicit operator task      | Repair, admin, or maintenance writes performed outside ordinary read-only request handling. | No                            | explicitly invoked tasks only                      |

The former W1-W7 preference GET writes and W14-W15 authentication GET writes were removed from the
allowlist on 2026-09-25 after checking the current request lifecycle. `set_preferences_cookie`
returns through read-only preference loading for `GET`/`HEAD`; `transparent_refresh_allowed?`
rejects browser navigation; and authenticated session activity tracking defaults off for
`GET`/`HEAD`. Preference transport records are changed only at their explicit write endpoints.
Provider sign-in, callback, and logout routes are absent from this process and are not active write
boundaries.

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
