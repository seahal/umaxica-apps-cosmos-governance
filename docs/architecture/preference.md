# Base Preference Architecture

Base app, org, and com own the local preference routes. Tech owns its separate operator RP and has no
preference route in this router. The former Auth, Warp, Core, Palm, Edit, and Publishing preference
surfaces are not served by this repository.

Base preferences are request-local projections over the realm's persisted preference records. The
Base controllers and existing preference concerns own preference reads, writes, browser bindings,
consent receipts, and localization. The com surface is anonymous and uses only its public preference
contract.

Auth and Visa URL configuration and local routes have been removed. Base preference reads and writes
remain local; sign-in and OIDC-driven step-up cannot start.

For current route details, see config/routes/base.rb. Preference model and database references are
part of the hard-reset model report; model and database deletion is deferred.
