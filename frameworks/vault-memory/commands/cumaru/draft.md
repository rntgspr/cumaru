# `/cumaru:draft`

Loads the `cumaru-draft` skill and creates or updates rough notes under
`drafts/`.

## Workflow

1. Load `.agents/skills/cumaru-draft/SKILL.md` and `roles/keeper.md`.
2. Load `drafts/index.md`.
3. Create or update `drafts/<slug>/index.md`.
4. Re-emit `drafts/index.md`.
5. Run `cumaru doctor`.
