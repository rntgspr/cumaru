---
human_revised: false
version: 1
name: cumaru-distill
description: Use this skill whenever the user wants to process inbox captures or drafts into permanent memory, produce graph nodes under memories, retain attachments, or clean processed inbox entries.
summary: Use this skill whenever the user wants to process inbox captures or drafts into permanent memory, produce graph nodes under memories, retain attachments, or clean processed inbox entries.
---

# `cumaru-distill` - create durable memory

Load `.cumaru/roles/keeper.md` plus the relevant `inbox/`, `drafts/`,
`memories/`, and `attachments/` indexes. Use invocation arguments to identify
the source material. Confirm before removing any processed inbox entry.

Distillation turns raw captures or drafts into self-contained memory nodes.
Inbox entries are removed after processing unless the user asks to retain them.

## Recipe: distill to memory

1. Read the source capture or draft and any listed files or URLs.
2. Decide whether the result should be:
   - a new `memories/<path>/index.md`
   - an update to an existing memory
   - a `drafts/` note
   - a retained `attachments/` entry
   - rejected/no durable output
3. For a memory, create or update the node from `templates/memory.md`.
4. Set frontmatter:
   - `type` as an open string
   - `confidence`
   - `last_update`
   - `summary`
   - `topics`
   - `references` for URLs
   - `derived-from` only for sources that will remain resolvable after cleanup:
     retained drafts, URLs, attachments, or other durable nodes
   - typed graph edges when known
5. Write `## Statement` as the durable memory.
6. Put nuance in `## Notes`.
7. Run `cumaru tree memories --rows` and inspect the affected parent directories.
8. Build the exact consumed-source set. Before removal, inspect every
   `derived-from` and relations-table edge that targets a consumed capture. Move
   source files that must remain to `attachments/<slug>/`, preserve stable URLs
   in `references`, and copy any necessary provenance fact into the durable
   memory's `## Notes`; then rewrite the edge to the retained source or remove
   it. Never leave an edge to a path selected for removal.
9. A source used by another active draft or memory is shared and must remain.
   Missing provenance or uncertain ownership blocks removal but does not undo
   the durable memory update.
10. With explicit user confirmation, remove only consumed
    `inbox/<capture-id>/` entries whose provenance has been reconciled. Git is
    not a prerequisite: a non-Git vault may complete distillation and authorized
    removal under this same retention boundary.
11. Run `cumaru doctor`.

## Graph guidance

Prefer typed relations over untyped prose:

- `relates`
- `supports`
- `contradicts`
- `supersedes`
- `superseded-by`
- `part-of`
- `similar-to`
- `derived-from`

Mirror the most important edges in the `relations` tag table.

## Patterns

| User says | You do |
|---|---|
| "process this inbox item" | Distill recipe |
| "make this permanent memory" | Create or update a memory node |
| "extract memories from this draft" | Distill draft statements into one or more memories |
| "delete the raw input after processing" | Remove the inbox capture after durable output is written |
