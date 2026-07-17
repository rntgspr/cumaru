---
human_revised: false
apps: [meta]
summary: Framework guidance for Memories and its required workflow.
---


# Memories

Durable graph-shaped memory nodes. These are the canonical facts, preferences,
decisions, product notes, concepts, procedures, and observations an agent may
load as permanent memory.

## Rules

- **One directory per memory node.** Use `memories/<slug>/index.md`; nested
  directories are allowed when they improve navigation.
- **Memory is self-contained.** A reader should understand the durable point
  without opening the original capture.
- **Use typed frontmatter freely.** `type` is an open string, not an enum.
- **Use typed graph edges.** Prefer `relates`, `supports`, `contradicts`,
  `supersedes`, `superseded-by`, `part-of`, `similar-to`, and `derived-from`
  when linking nodes.
- **Use references honestly.** URLs are evidence; search strings are refresh
  queries, not proof.

## When to use

- A durable memory worth loading in future sessions.
- A graph node that connects to other memories.
- A subject page such as `memories/cars/nissan/murano/index.md`.

## When NOT to use

- Raw captures -> `inbox/`.
- Rough notes or unresolved thinking -> `drafts/`.
- Large retained files -> `attachments/`.
