---
human_revised: false
summary: Framework command guidance for `/cumaru:distill` workflow execution.
---

# `/cumaru:distill`

Loads the `cumaru-distill` skill and turns inbox captures or drafts into durable
memory nodes.

## Workflow

1. Load `.agents/skills/cumaru-distill/SKILL.md` and `roles/keeper.md`.
2. Load the relevant `inbox/`, `drafts/`, `memories/`, and `attachments/`
   indexes.
3. Read the source capture or draft.
4. Create or update `memories/<path>/index.md`.
5. Retain attachments only when needed.
6. Clean processed inbox entries with confirmation.
7. Run `cumaru doctor`.
