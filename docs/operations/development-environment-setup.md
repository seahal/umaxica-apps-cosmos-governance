# Development Environment Setup

Status: draft. Sections marked "To be written" are placeholders for content that has not been
verified yet.

This guide collects, in order, the steps needed before the application runs locally, other than
database preparation and seeding. Each step links to the document that owns the details.

## 1. Host prerequisites

Install Podman 5 or newer, `podman-compose`, VS Code, and the Dev Containers extension, then apply
the one-time host configuration in
[devcontainer-cli-podman-startup.md](devcontainer-cli-podman-startup.md). Podman-specific caveats
are in [container-engine-podman-notes.md](container-engine-podman-notes.md).

## 2. Material that is not in git

Obtain and place the items listed in
[development-credential-provisioning.md](development-credential-provisioning.md):

- `config/credentials/development.key` and `config/credentials/test.key`, from the development lead.
  Never generate them with `bin/rails credentials:edit`.
- The repository-root `.env` with its documented local infrastructure settings.

## 3. Cloudflare tunnel

A development tunnel is used for Base and Tech host access and operator tools. Configure it following
[cloudflare-private-origin.md](cloudflare-private-origin.md). Confirm the retained Base and Tech
route hosts reach this deployment. OpenID Provider sign-in is unavailable in this repository.

## 4. Start the development container

Follow [devcontainer-cli-podman-startup.md](devcontainer-cli-podman-startup.md). Port exposure rules
are in [development-host-port-exposure.md](development-host-port-exposure.md), and the available
container targets are in [development-container-targets.md](development-container-targets.md).

## 5. Databases

Database creation, migration, and seeding are covered by [db-workflow.md](db-workflow.md) and
[test-environment.md](test-environment.md). They are out of scope for this guide.

## 6. Local AWS substitute

To be written: when [local-aws-fakecloud.md](local-aws-fakecloud.md) is required for local work.

## 7. Identity sign-in status

Auth and Visa URL configuration and their local routes have been removed. Base and Tech OIDC
sign-in, callbacks, sign-out, Back-Channel Logout, and OIDC-driven step-up are unavailable. This
repository does not call those authorities.

## 8. Other external services

To be written: Cloudflare Turnstile ([../security/turnstile.md](../security/turnstile.md)), passkeys
([passkey.md](../runbooks/passkey.md)), and any other service that needs per-environment
configuration.

## 9. Verify the environment

To be written: the smallest set of checks that confirm a working setup.
