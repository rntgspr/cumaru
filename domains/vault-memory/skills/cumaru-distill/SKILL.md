---
human_revised: false
version: 1
name: cumaru-distill
description: Use this skill whenever the user wants to process inbox captures or drafts into permanent memory, produce graph nodes under memories, retain attachments, or clean processed inbox entries.
summary: Use this skill whenever the user wants to process inbox captures or drafts into permanent memory, produce graph nodes under memories, retain attachments, or clean processed inbox entries.
---

# `cumaru-distill` - create durable memory

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
   - `derived-from` for captures, drafts, URLs, or attachments
   - typed graph edges when known
5. Write `## Statement` as the durable memory.
6. Put nuance in `## Notes`.
7. Run `cumaru tree memories --rows` and inspect the affected parent directories.
8. If local source files must remain, create `attachments/<slug>/index.md` and
   move/copy the files there with user confirmation.
9. Remove processed `inbox/<capture-id>/` by default, after confirming when it
   contains local files.
10. Run `cumaru doctor`.

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
