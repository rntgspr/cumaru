# `/cumaru:capture`

Loads the `cumaru-capture` skill and creates an `inbox/` capture for raw
material.

## Workflow

1. Load `.agents/skills/cumaru-capture/SKILL.md` and `roles/keeper.md`.
2. Load `inbox/index.md`.
3. Classify the capture type.
4. Create or update `inbox/<capture-id>/index.md`.
5. Re-emit `inbox/index.md`.
6. Run `cumaru doctor`.
