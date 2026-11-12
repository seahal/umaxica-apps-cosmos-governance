# Preference Behavior Contract

This document describes the Base app, org, and com Preference behavior. The WU-9 shape migrations
were approved and applied to the eight local development/test databases. Final behavior acceptance
remains pending.

## Ownership

Base app, org, and com write through `PreferenceWriteBoundary`. The writer receives its realm and
operation through the closed surface map. Request parameters and cookies cannot choose an account or
a Preference row for persistence. A Preference JWT is a signed read projection; it never creates a
database row by itself. Browser cookies are never copied into Preference tables.

Interactive browser Preference controls and browser-bound state are Base-owned. Tech has no
Preference routes. No cross-surface sign-in or sign-out flow reads or writes Preference state.

## Anonymous JWT and browser state

The anonymous JWT carries one closed `preferences` object with theme, language, timezone, currency,
date format, time format, motion, density, and page size. It identifies its row using `sub` and its
realm using `aud`; it contains no account ID, consent, region, Web Push state, binding, or OIDC
session. The display projection uses the same database snapshot to issue the JWT, `language`, and
`__Secure-experience` cookies. The registered `infinity` page-size option is valid. The anonymous
JWT uses the option name `preferences.theme`; Base's Preference write response uses the short `ct`
code (`li`, `dr`, or `sy`) for that same value.

The host-only `__Host-preference_binding` cookie is issued only by Base saves that change consent or
Web Push. Its digest is stored on the matching anonymous row. Consent decisions are stored in
`*_preference_cookies` with a versioned receipt child; Web Push uses an option reference, not a
boolean column.

GET and HEAD do not create or refresh Preference rows, rotate credentials, or extend cookie expiry.
An invalid or missing JWT may be followed by an explicit write that creates a new default row. An
invalid JWT does not authorize mutation of the row it names. Base app/org/com HTML GET and HEAD
requests build `Actor.preferences` from verified JWT display values plus the active anonymous row's
region. Consent and Web Push are included only when the current realm, JWT expiry, consent receipt,
and host-only browser binding authorize the browser; consent version and decision time come from
that receipt. Missing or mismatched browser binding produces declined consent and disabled Web Push.
Base JSON API reads keep state in their response and do not project it into the request Actor. A
read failure is logged and leaves safe Actor browser defaults in place. Base app/org browser API GET
and HEAD requests run the display-cookie transport: a verified token with missing or mismatched
display mirrors rebuilds the two display cookies from the authorized actor projection, active
anonymous row, or defaults. This does not change the JWT, row lifecycle, expiry, or browser binding.
An unusable token causes Base to clear only shared cookies that were present. Unsafe API requests
skip this read transport and issue cookies only through the completed Preference writer.

## Actor-local preference

`ClientPreference` and `OperatorPreference` own account-local preference state in their respective
principal databases. Display values are stored in option-backed child records. After the approved
shape cutover, `explicit_fields` is a NOT NULL list of fields that the person explicitly chose.
Unknown historical provenance is never inferred from child values. A row without a usable explicit
field list cannot contribute values to an actor Preference projection.

A region save updates region plus its fixed language, date format, time format, and currency values
in the same actor write, then records those submitted fields as explicit. `adult_content_gate`
remains dormant in model/option/child tables and is absent from runtime registries and write paths.

## Failure and transaction boundaries

- Base actor saves authorize the authenticated actor and only persist submitted fields. The actor
  database write and anonymous setting write have separate database owners; a partial failure is
  reported as a failed Preference save, not as a complete save.
- Unknown fields, malformed JWTs, ambiguous duplicate JWT cookies, invalid option values, missing
  required child records, and cross-realm writer requests fail explicitly.
- App, org, and com use the same `PreferenceWriteBoundary` operations. Their rows, option IDs,
  binding digests, and Web Push records remain realm-local.

## Retired paths

`PreferenceAdoption`, Preference refresh tokens, Preference DBSC/assurance state, per-item cookies,
and actor consent mirrors are retired. Authentication-token model state is separate from Preference
state; retained DBSC fields do not refresh or bind Preference rows.

## Acceptance state

Runtime implementation and reference documentation describe the WU-9 contract. The shape cutover
has run locally. Behavior acceptance remains incomplete until the app/org/com acceptance set and the
single closing full-suite comparison are recorded in `evidence/`.
