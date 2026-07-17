---
name: cumaru-v4-model-and-universal-tag-shape
description: "The v4 framework — every <!-- cumaru:NAME --> marker block is a [Link, Description] markdown table, hardcoded in the parser. Schemas no longer declare per-tag columns."
metadata:
  node_type: memory
  type: project
---

> Historical model. V5 superseded the universal tag shape with schema-declared
> body types; V6 superseded structural tag inventories with filesystem-backed
> `cumaru tree` navigation. See [[v6_virtual_tree]].

**v4 schema model (carried from v3).** `schema.yaml` is one recursive node tree under `root:`. Every node — root and every descendant — shares one shape `{path?, frontmatter?, tags?, entities?}`. Pillars (`intake`, `plans`, `archive`, `specs|topology|coverage`, `exploring`, `runbooks|standards`) are children of `root`. Frontmatter contract uses `!` suffix for required keys.

**v4's load-bearing change — the universal tag shape.** Every `<!-- cumaru:NAME --> ... <!-- /cumaru:NAME -->` block is a markdown table with exactly two columns:

```
| Link                  | Description                                |
|-----------------------|--------------------------------------------|
| [name](path/index.md) | one-line prose explaining the linked file  |
```

This applies to ALL tags: pillar indexes (intake/plans/archive/specs/exploring/topology/runbooks/coverage/standards), `<!-- cumaru:components -->` on `domain.md`, `<!-- cumaru:root -->` on `domain.md`, `<!-- cumaru:files -->` and `<!-- cumaru:touched -->` anywhere, `<!-- cumaru:templates -->` on `templates/index.md`. No exceptions.

**Schema implication.** Per-tag declarations no longer carry `columns:`, `format:`, `description:`, or `number:`. The only sub-key that survives is `host_file:` (and only for meta tags that live outside the node tree). Tag entries become `{}` or `{ host_file: ... }`. The shape is **hardcoded** in the parser, `cumaru tag`, `cumaru doctor`, and `cumaru update` — it is a cannon system rule, not a per-tag concern.

**Why this change.** v3 carried 6+ different column sets across the four domains (e.g. specs `[Path, Summary, Apps, Depends-on, Relates]`, archive `[Key, Type, Apps, Summary, Absorbed-in]`, intake `[Key, Type, Title, Status, Relates]`). Half the info repeated what was already in frontmatter; the other half was prose squeezed into a column. Renato's call: collapse every row to "a link + one line of prose about it" and trust the LLM to write a useful Description. Side-effect: parser, doctor, update, tag CLI all lose entire branches (table-column-diff, path-list, string-kind, number-seed).

**Tracker-agnostic and flat intake (carried from v3).** Every intake item lives at `intake/<KEY>/`, carrying `key` + `type` + `relates`. Backing tracker named once by `tracker:` on `intake/index.md`. Wired: jira, linear, clickup. The Key/Type/Title/Status/Relates columns of v3 are gone — the row is just `[KEY](KEY/index.md) | <type, status and one-line title>`. The richer fields live in each item's frontmatter, unchanged.

**Specs/topology/coverage tree-shaking (carried from v3).** Areas nest subareas. `depends-on:` = hard (load it); `relates:` = soft (consider). The Description column in the index row is where the LLM writes the one-line summary it used to put under "Summary" in v3.

**Status (2026-06).** v4 schema landed across all 4 domains. Parser/CLI adaptation, starter rewrite, skill updates, docs sweep, and the v3→v4 migration are the next passes. Renato chose direct work on `main` (no branch) following the squash-to-sunrise pattern from earlier domains.

**How to apply.** The schema is still the source of truth for which pillars exist and which frontmatter keys are required. It is NOT the source of truth for tag column layouts anymore — that is a single hardcoded constant. When authoring or updating any `<!-- cumaru:* -->` block (in starters, templates, skills, or recipes), the body is always `| Link | Description |`. Never invent extra columns.
