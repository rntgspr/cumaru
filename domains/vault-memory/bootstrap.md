---
summary: Ordered bootstrap steps for the vault-memory domain after install.
---

## vault-memory — bootstrap steps

The install ships empty `inbox/`, `drafts/`, `memories/`, and `attachments/`
pillars. Work through the steps in order. Where a step allows a proposal,
present it and write only what the user confirms. `disciplines/`, `roles/`,
and `templates/` stay as shipped.

1. **Memory domains.** Ask for the vault's major domains or external
   collections, and replace the `components` tag in `domain.md` with them
   using `cumaru tag`.
2. **Targets.** Update `config.yaml > meta.targets.values` only when the user
   wants a custom domain axis.
3. **Loose notes.** When the user brings existing notes, ask what starts as
   `drafts/` versus `memories/`; never classify in bulk without confirmation.
4. **Hand-off.** `cumaru-capture` files raw material into `inbox/` from
   `templates/capture.md` and `attachments/` from `templates/attachment.md`;
   `cumaru-draft` writes rough notes from `templates/draft.md`;
   `cumaru-distill` writes permanent nodes from `templates/memory.md` and
   `templates/term.md`; `cumaru-link` records graph relationships. New pillar
   indexes start from `templates/any-index.md`.
5. **Validate.** Run `cumaru doctor`, then report answered and empty topics.
