# Model and Database Inventory

This document records the model and database boundary after the 2026-11-11 surface hard reset.
The route and controller reset deliberately did not delete models, migrations, schemas or database
configurations. The next database cleanup step should use the detailed per-model caller inventory in
[evidence/2026-11-11-surface-hard-reset-V4N8.md](../../evidence/2026-11-11-surface-hard-reset-V4N8.md).

That evidence classifies each concrete `ApplicationRecord` model by its configured write database:

- **USED** means at least one non-model application file references a model constant.
- **ONLY-VIA-MODELS** means references remain in model files or tests, with no non-model application
  reference found by the inventory scan.
- **UNUSED** means no model, test or non-model application reference was found, or a configured
  database has no concrete application models assigned to it.

The scan uses eager-loaded model descendants and textual constant references. It is an inventory for
the follow-up review, not proof that a database is safe to delete: framework-owned records, dynamic
constant lookup, SQL, reflection and operational tooling may not appear as Ruby constant references.
No database was dropped as part of the surface reset.
