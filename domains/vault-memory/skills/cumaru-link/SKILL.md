---
human_revised: false
version: 1
name: cumaru-link
description: Use this skill whenever the user wants to connect memories, add typed graph relationships, find related nodes, mark contradictions, supersede stale memories, or improve memory graph navigation.
summary: Use this skill whenever the user wants to connect memories, add typed graph relationships, find related nodes, mark contradictions, supersede stale memories, or improve memory graph navigation.
---

# `cumaru-link` - maintain typed graph edges

Load `.cumaru/roles/keeper.md` before using invocation arguments to identify
the memories and edge type.

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
3. Update both sides when the relationship is naturally reciprocal:
   `contradicts` and `similar-to` on both nodes, `supersedes` paired with
   `superseded-by`.
4. Keep `status` consistent with the edge:
   - a new `contradicts` sets both nodes to `status: disputed`
   - resolving it keeps one node as `status: canonical` and sets the other to
     `status: superseded` with `superseded-by` and `valid-until`; remove the
     `contradicts` edge from both nodes
   - decide by the `authority` ranking in `domain.md`; ask the user only on
     equal or unknown rank
   - never delete a superseded node; it answers "what was true before"
5. Update the `<!-- cumaru:relations -->` table when the edge should be visible
   during traversal.
6. Run `cumaru doctor`.

## Patterns

| User says | You do |
|---|---|
| "link Murano to gasoline cars" | Add `relates` or `part-of`, then update relations table |
| "this memory replaces that one" | Add `supersedes` and `superseded-by` |
| "these two conflict" | Add `contradicts` on both nodes and set both `status: disputed` |
| "this one is right" | Resolve the dispute: `canonical` here, `superseded` there |
| "list open conflicts" | Search `memories/` frontmatter for `status: disputed` and list those nodes |
