# Preference lifecycle

Use this checklist when changing anonymous or account-local Preference state on APP, ORG or COM. It
records required behavior; passing items require current-session test evidence.

- PREF-1: Base app, com and org are the only retained Preference surfaces. Provider sign-in and
  sign-out Preference writes have no local route or caller.
- PREF-2: A successful Base GET or HEAD does not create, update, retire, or issue Preference state.
- PREF-3: Anonymous state is a realm-scoped signed Preference JWT and the shared `language` and
  `__Secure-experience` cookies. No per-item, Preference refresh, or Preference DBSC cookie is
  issued or consumed.
- PREF-4: Base save changes only submitted fields. Web Push is stored through its option foreign
  key. Consent receipts and browser bindings remain browser-local.
- PREF-5: A Preference persistence failure does not misreport a successful same-surface Preference
  write. Preference cookies are emitted only after the Preference setting transaction succeeds.
- PREF-8: Reset retires the old anonymous row and any active account-local row, creates the
  anonymous replacement, issues the three shared cookies, and deletes the old binding cookie.
- PREF-9: APP, ORG and COM reject each other's Preference row/token authority. Cross-realm state is
  never copied.
- PREF-10: `PreferenceAdoption`, Preference refresh/DBSC/assurance, item cookies and actor consent
  mirrors have no runtime callers. Authentication-token model state is separate from Preference
  state, and DBSC runtime endpoints are absent.
- PREF-11: `adult_content_gate` has no non-model runtime reference. Its models, option records and
  child tables remain dormant and are not removed as part of Preference cutover.
- PREF-12: Any destructive local schema cutover has an approved execution ticket, refreshed row
  counts and recovery snapshot before application. Production and Neon remain outside local
  acceptance work.
- PREF-13: Base app/org/com alone render interactive Preference controls and read browser-bound
  consent and Web Push state. No other product surface is served by this process.
- PREF-14: The public retention job purges expired anonymous APP, ORG, and COM rows only after the
  owner-database expiry plus 30-day grace period, rechecks the deadline under lock, and retains any
  row referenced by a matching typed Preference chronicle as subject or actor; a different subject
  type with the same numeric ID remains independent and survives Preference deletion.
- PREF-15: Base app/org/com HTML GET and HEAD requests project the active row's region and only the
  receipt- and browser-bound consent/Web Push state into `Actor.preferences`. JSON APIs leave that
  Actor unchanged, mismatched bindings produce declined/disabled state, and non-Base hosts read none
  of the browser-bound setting state.

This checklist records contract requirements, not test results. See
[Preference architecture](../architecture/preference.md).
