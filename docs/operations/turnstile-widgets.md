# Cloudflare Turnstile Widgets (Development)

This page covers the Governance repository's development widgets only. Staging uses the account's
`staging-stealth` and `staging-visible` widgets, and production is not configured here.

## This Repository: Governance

| Item              | Value |
| ----------------- | ----- |
| Widgets           | `governance-development-stealth` (`0x4AAAAAAF53DtjqKSQaygca`), `governance-development-visible` (`0x4AAAAAAF53EmvNvRoFt14O`) |
| Allowed hostnames | `www.umaxica.{app,org,com,dev}`, `tech.umaxica.org` |
| Origin            | created 2026-11-09 for this repository alone |

The stealth widget is `invisible` mode and the visible widget is `managed` mode; both use region
`world` and clearance level `interactive`. Site keys are public. Secret keys are never written to
documents, logs or the conversation.

## Where the Keys Live

The application reads the keys through `Rails.app.creds` (environment variable first, then
credentials) under these names, stored in `config/credentials/development.yml.enc`:

- `CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY`, `CLOUDFLARE_TURNSTILE_SECRET_STEALTH_KEY`
- `CLOUDFLARE_TURNSTILE_VISIBLE_SITE_KEY`, `CLOUDFLARE_TURNSTILE_VISIBLE_SECRET_KEY`

A site key and its secret key must change together; a mismatched pair fails every verification.
Running Rails processes read credentials at boot, so restart them after a change.

## Rotating or Replacing Keys

1. In Cloudflare, open Turnstile, select the widget and rotate its secret (or create a new widget).
2. Inside this repository's Dev Container run
   `bin/rails credentials:edit --environment development` and replace the pair.
3. Restart Rails and submit a form protected by each widget.

## Notes

- The widgets list only public hostnames. Pages opened through `*.localhost` may fail the challenge
  unless the hostname is added to the widget.
- On 2026-11-09 the secret keys of the six new widgets passed through an assistant conversation while
  being written to credentials. They are development keys; rotate them if that exposure matters.
