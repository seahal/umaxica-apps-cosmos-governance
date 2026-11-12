# Documentation Index

This index links to current repository guidance. Historical records remain in their owning
directories and do not define the current Rails surface.

- [Knowledge architecture](reference/repository-knowledge-architecture.md): document ownership,
  authority and maintenance.
- [Durable checklists](checklists/README.md): behavior that must keep working.
- [Risk management](risk-management/README.md): actual risks, responses and ownership.
- [Specifications](../specs/README.md): accepted change scope, evidence and closure.
- [Runbooks](runbooks/README.md): operator procedures for deployed environments and dependencies.
- [Development setup](operations/development-environment-setup.md): verified local setup guidance.
- [Subdomain map](reference/subdomains.md): the hosts and route families served by this repository.
- [Current surface matrix](architecture/content-surface-matrix.md): retained and retired surface
  ownership.
- [Controller boundaries](architecture/controller-boundaries.md): controller and route ownership.
- [Database boundaries](architecture/database-boundaries.md): current database placement and
  authority.
- [Model/database inventory](architecture/model-database-inventory.md): current model placement.
- [Preference behavior](architecture/preference-behavior-contract.md): persisted preference
  behavior and ownership.
- [Health endpoints](reference/health-endpoints.md): the retained health and readiness contracts.
- [Security observability](security/observability-boundary.md): logging and audit boundaries.
- [Redirect targets](security/redirect_targets.md): validated redirect and navigation behavior.

Repository prose is English. Follow the
[repository language policy](reference/repository-language-policy.md). Keep current descriptions
aligned with delivered behavior; historical evidence remains in flat `evidence/` Markdown records
named `YYYY-MM-DD-<topic>-XXXX.md`, with the full source revision and worktree qualification.
