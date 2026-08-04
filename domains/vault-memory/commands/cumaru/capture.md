---
version: 1
description: Capture raw material in the memory vault inbox.
human_revised: false
summary: Framework command guidance for `/cumaru:capture` workflow execution.
---

# `/cumaru:capture`

Loads the `cumaru-capture` skill and creates an `inbox/` capture for raw
material.

## Workflow

1. Load the installed `cumaru-capture` skill and `.cumaru/roles/keeper.md`.
2. Load `inbox/index.md`.
3. Classify the capture type.
4. Create or update `inbox/<capture-id>/index.md`.
5. set the affected entity `summary:` and run `cumaru tree --rows`
6. Run `cumaru doctor`.
