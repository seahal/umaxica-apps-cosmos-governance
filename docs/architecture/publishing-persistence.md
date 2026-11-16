# Publishing Persistence Boundary

The Publishing tables and model namespace remain in this hard-reset step because models and
migrations are explicitly deferred. The former Docs, Help, Info, and News controllers, views, and
routes have been removed from this repository.

No current Rails route renders or mutates Publishing content. The Publishing model classes are
referenced only through the remaining model layer; the database is classified as
`ONLY-VIA-MODELS` in the hard-reset report. Do not infer a local Publishing surface from the
retained schema.

A later model/database cleanup can remove the unused Publishing persistence after its data-retention
and recovery scope has been decided. This document records the current route boundary, not the
history of the Publishing schema.
