---
name: regen-and-cross-file-checks-cleanup
description: Removed stale cumaru regen references and unused schema cross_file_checks metadata
metadata:
  type: project
---

Decision (2026-07-10): `cumaru regen` is not a current CLI command and should not be referenced.

Cleanup performed:

- Removed stale `regen` references from comments/templates/roles.
- Replaced "regenerate indexes" wording with "update index tables".
- Removed unused `meta.cross_file_checks` blocks from all domain schemas.
- Replaced docs/skills/help text that pointed to `meta.cross_file_checks.deferred` with direct wording: cross-file semantic checks are not enforced by `cumaru doctor`.

Reason: no script reads `cross_file_checks`; keeping it in schemas implied a tool contract that does not exist.
