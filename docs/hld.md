# High-Level Design

This Rails application serves Base app, Base org, Base com, Tech org and repository-local operator
tools. The [current surface matrix](architecture/content-surface-matrix.md) owns the route boundary;
the [controller boundaries](architecture/controller-boundaries.md) document its request lifecycle.

Each product surface has a separate host constraint and controller namespace. Base app and Base org
share only the explicit Base abstractions in the application. Base com is an anonymous public
surface. Tech org is an operator surface. Operator tools use dedicated host constraints and their
own access controls.

Auth, Visa, Core, Warp, Palm, Edit, Docs, News, Help, Info and Guid routes and controllers have been
retired from this repository. Auth/Visa URL configuration is removed, so Base and Tech OIDC
sign-in, callbacks, RP-initiated sign-out, Back-Channel Logout, and OIDC-driven step-up are
unavailable. Existing Base RP credentials are validated only through the retained local session
boundary.

Models and migrations remain in place for the separate model/database cleanup step. The
[surface hard-reset evidence](../evidence/2026-11-11-surface-hard-reset-V4N8.md) records the route
inventory, remaining model callers and database classification.
