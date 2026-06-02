---
human_revised: false
version: 1
name: cumaru-link
description: Use this skill whenever the user wants to connect memories, add typed graph relationships, find related nodes, mark contradictions, supersede stale memories, or improve memory graph navigation.
---

# `cumaru-link` - maintain typed graph edges

Memory relationships are first-class frontmatter fields. The `relations` table
is a human-readable mirror of the most important edges.

## Recipe: link memories

1. Read the relevant memory nodes and `memories/index.md`.
2. Choose the relation type:
   - `relates`
   - `supports`
   - `contradicts`
   - `supersedes`
   - `superseded-by`
   - `part-of`
   - `similar-to`
   - `derived-from`
3. Update both sides when the relationship is naturally reciprocal.
4. Update the `<!-- cumaru:relations -->` table when the edge should be visible
   during traversal.
5. Run `cumaru doctor`.

## Patterns

| User says | You do |
|---|---|
| "link Murano to gasoline cars" | Add `relates` or `part-of`, then update relations table |
| "this memory replaces that one" | Add `supersedes` and `superseded-by` |
| "these two conflict" | Add `contradicts` on both nodes |
