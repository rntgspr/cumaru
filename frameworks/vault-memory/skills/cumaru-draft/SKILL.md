---
human_revised: false
version: 1
name: cumaru-draft
description: Use this skill whenever the user wants to write or organize rough notes, guided thinking, exploratory notes, or messy subject notes that may later become permanent memory.
---

# `cumaru-draft` - maintain rough notes

Drafts are durable working notes. They are not permanent memory until distilled.

## Recipe: create a draft

1. Agree on a kebab-case `<slug>`.
2. Create `drafts/<slug>/index.md` from `templates/draft.md`.
3. Set `summary`, `topics`, `source`, and `derived-from` when relevant.
4. Write freeform notes in `## Notes`.
5. Add candidate durable statements under `## Possible Memories`.
6. Re-emit `drafts/index.md` with `cumaru tag set drafts/index.md drafts`.
7. Run `cumaru doctor`.

## Recipe: promote draft material

1. Read the draft and identify durable statements.
2. Hand off to `cumaru-distill`.
3. Keep the draft when it remains useful; otherwise ask before removing it.

## Patterns

| User says | You do |
|---|---|
| "let's jot this down" | Create or update a draft |
| "turn this capture into notes" | Create a draft with `derived-from` pointing to inbox |
| "does this draft contain memories?" | Extract candidate statements and hand off to `cumaru-distill` |
