# Preference And Settings Authority

## Local routes

Base app, org, and com own the preference routes served by this repository. Base app and org retain
their local identity and account-management routes. Tech owns its operator surface.

Auth and Visa URL configuration and local routes have been removed. Base and Tech OIDC sign-in,
sign-out, and OIDC-driven step-up are unavailable; this repository makes no calls to those
authorities.

## Persistent state

Foreign-surface preference and RP tables remain because model and database deletion is deferred.
Their presence does not mean this repository serves those surfaces. The model/database report in
the surface hard-reset evidence records which remaining classes have non-model callers.

## Related

- docs/architecture/preference.md
- docs/architecture/content-surface-matrix.md
