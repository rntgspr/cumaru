---
human_revised: false
generated: true
generated-at: 2026-07-05T00:00:00Z
apps: [meta]
---

<!-- cumaru:memories -->
| Link | Description |
|------|-------------|

_No memories yet. Each row links to `memories/<path>/index.md` with a one-line statement of the durable memory._
<!-- /cumaru:memories -->

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
