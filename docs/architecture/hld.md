# High-Level Design

## Purpose

This document describes the current high-level architecture for the global Rails application.

## Architecture Overview

The repository is a single Rails app with three user-facing surfaces:

| Surface | Responsibility                     |
| ------- | ---------------------------------- |
| `app`   | End-user product and account flows |
| `org`   | Staff and organization workflows   |
| `com`   | Public and corporate workflows     |

This repository serves the Base app/com/org and Tech org surfaces plus its host-constrained operator
tools. Base and Tech are browser RPs; credential and OpenID Provider authorities are external
dependencies. Former Auth, Visa, Core, Warp, Palm, Edit, content, and Guid route/controller trees
are retired; remaining models and databases are inventoried for a later cleanup step.

## Routing

- `config/routes.rb` draws route fragments for the app.
- Route fragments apply host constraints and surface-local modules.
- New work should use RESTful routes and path helpers.
- Do not introduce local Rails Engines, wrapper apps, or cross-engine routing proxies.

## Data Ownership

Surface-owned database names follow the `surface_role` model documented in
`docs/architecture/database-boundaries.md`.

Cross-cutting and infrastructure databases remain separate, including `occurrence`, `chronicle`,
`avatar`, `search`, `queue`, and `storage`. There is deliberately no `cache` database: application
cache is Valkey-backed (`CACHE_REDIS_URL`) and non-authoritative.

## Quality Goals

- Keep surface boundaries explicit.
- Keep authentication, authorization, verification, CSRF, and rate-limit order intact.
- Keep business logic out of controllers.
- Keep database ownership readable through base records and connection names.
- Keep regional content concerns out of this repository unless a current ADR says otherwise.
