# High-Level Design

This Rails application serves Base app, Base org, Base com, Tech org and repository-local operator
tools. The [current surface matrix](architecture/content-surface-matrix.md) owns the route boundary;
the [controller boundaries](architecture/controller-boundaries.md) document its request lifecycle.

Each product surface has a separate host constraint and controller namespace. Base app and Base org
share only the explicit Base abstractions in the application. Base com is an anonymous public
surface. Tech org is an operator surface. Operator tools use dedicated host constraints and their
own access controls.

Auth, Visa, Core, Warp, Palm, Edit, Docs, News, Help, Info and Guid provider and product surfaces
have been retired from this repository. Governance does not host Visa authorization or credential
ceremonies. Base App and Base Org have separate RP entries, callbacks, local sign-out and
Back-Channel Logout receivers; Visa handoffs navigate through Jump. Access's Visa Org authorization
endpoint currently answers 503, and OIDC-driven step-up is absent. Existing Base RP credentials are
validated through each realm's retained local session boundary.

Models and migrations remain in place for the separate model/database cleanup step. The
[surface hard-reset evidence](../evidence/2026-11-11-surface-hard-reset-V4N8.md) records the route
inventory, remaining model callers and database classification.
