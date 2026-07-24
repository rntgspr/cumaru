---
version: 1
description: Update typed relationships between durable memory nodes.
human_revised: false
summary: Framework command guidance for `/cumaru:link` workflow execution.
---

# `/cumaru:link`

Loads the `cumaru-link` skill and updates typed graph relationships between
memory nodes.

## Workflow

1. Load the installed `cumaru-link` skill and `.cumaru/roles/keeper.md`.
2. Load `memories/index.md` and relevant memory nodes.
3. Choose the relationship type.
4. Update frontmatter and `relations` tables.
5. Run `cumaru doctor`.
