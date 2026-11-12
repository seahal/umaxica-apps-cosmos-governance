# Inertia History and Page Props

Inertia stores each visited page object and its props in browser history so Back can restore the page
without another request. History is encrypted, but the decryption key remains in the tab's
sessionStorage. Ending a Rails session does not remove that key. A page that ends an authenticated
state transition or displays a one-time secret must therefore clear history.

## Current local events

| Event | Mechanism | Owner |
| --- | --- | --- |
| Base withdrawal or credential removal | Clear history before the terminal redirect/render | Base identity controllers and concerns |
| One-time secret display and step-up completion | Clear history on the one-time result page | Base identity and verification flows |

Ordinary navigation must not clear history; doing so would break Back for every page.

The session flag survives redirects only. The Inertia middleware deletes it on every non-redirect
response, including plain HTML pages. A terminal page must either render Inertia with
clear_history enabled, redirect to such a page, or send Clear-Site-Data with storage.

## Page props

Inertia embeds the full page object in the HTML or the JSON body of an Inertia visit. Every prop is
readable in the page source and remains in history until cleared. Props must:

- include only fields the page displays or needs to act, built field by field rather than by
  serializing a record;
- expose public references rather than database identifiers;
- never carry tokens, credential digests, hashes, keyed proofs, or another actor's data;
- keep shared props free of personal data; and
- be built only after authorization.

A one-time secret may appear only on its one-time display page, which clears history.

## Verification

Current tests cover authenticated response caching, withdrawal, and runtime role restrictions on
development tooling. Route-contract tests assert that removed Auth/Visa sign-in and sign-out routes
are absent. Historical Auth, Visa, Warp, Palm, Core, and Edit coverage has been removed with those
local surfaces.

A full audit of page props remains open in
plans/backlog/2026-10-20-inertia-props-exposure-audit.md.
