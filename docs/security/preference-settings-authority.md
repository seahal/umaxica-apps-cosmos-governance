# Preference And Settings Authority

## Local routes

Base app, org, and com own the preference routes served by this repository. Base app and org retain
their local identity and account-management routes. Tech owns its operator surface.

Governance does not host Auth or Visa credential ceremonies. Base App has a relying-party entry,
callback, sign-out and Back-Channel Logout receiver; Base Org has the same RP flow in its own
`rp_base_org` cell. Those flows use the external Visa and Jump contracts. OIDC activity does not
read or write Preference state. Tech remains disconnected, and OIDC-driven step-up remains absent.

## Persistent state

Foreign-surface preference and RP tables remain because model and database deletion is deferred.
Their presence does not mean this repository serves those surfaces. The model/database report in the
surface hard-reset evidence records which remaining classes have non-model callers.

## Related

- docs/architecture/preference.md
- docs/architecture/content-surface-matrix.md
