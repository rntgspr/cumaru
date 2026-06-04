---
human_revised: false
generated: false
framework-version: 3
apps: [meta]
depends-on: [domain.md]
---

<!-- llm:components -->
| Key | Folder | Stack/Notes |
|---|---|---|
_(replace with your actual stack)_
<!-- /llm:components -->

<!-- llm:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /llm:root -->

# `.llm/`

Entry point for any LLM (or human) interacting with this repository. **This file is identical across every flavor** — it is the framework kernel, sourced from `__base`. Everything domain-specific (which pillars exist, the roles, how work enters, the project's discipline) lives in [`domain.md`](domain.md), declared as this index's `depends-on` and pulled in by the rule below.

## The model — one recursive node

The whole `.llm/` tree is described under `schema.yaml`'s `root:` key. **`root` is the top node** (the `.llm/` directory itself); its children are the **pillars** (declared per flavor). Every node shares one shape:

```
{ path?, frontmatter?, tags?, entities? }
```

- **`path`** — the node's dir/file, relative to its parent (implicit = the key).
- **`frontmatter`** — the node's `index.md` frontmatter contract (`!` = required).
- **`tags`** — marker blocks in the node's `index.md`; an array tag is a table whose marker name is the colon-joined path through the tree.
- **`entities`** — child nodes, recursive, same shape.

A node's `index.md` table is the **shallow index** — the only thing that enters context by default for that node. It carries only columns that orient a decision; heavy references live in entity frontmatter, reached by drilling in.

<!-- BEGIN __base:loading-rule — canonical, framework-owned prose. Synced VERBATIM into every flavor's index.md; edit here, then propagate. Ordinary HTML comment, NOT an `llm:` tag, so `llm update` carries it from source. -->
## Loading rule

The LLM loads only what is **declared** — never what is physically near on disk. What can be declared comes from two places: the schema (which pillars and nodes exist) and each node's own index (which candidates it lists). Loading is a **guided traversal** of that tree, not a bulk read — at each step the structure proposes candidates and the LLM prunes them by relevance to the task. The structure proposes; the LLM disposes.

1. **A role is on duty.** The role declares which shallow index(es) enter context to begin. An index is a *map* of what exists — cheap tokens; drilling into a node is a separate, deliberate act.
2. **The task fixes a subject.** Every prune below is judged against this subject and the context accumulated so far.
3. **Expand the current index** into its declared candidates: the union of the entries the index itself lists (its children, via its table or file list) and the nodes named in its `depends-on` and `relates` frontmatter. Each candidate carries a one-line subject and resolves to either another index or a leaf file.
4. **Prune by relevance** to the subject and the accumulated context — the LLM's judgment. `depends-on` is the strongest signal; `relates` is "consider".
5. **Load the survivors.**
6. **Recurse.** Every survivor that is itself an index repeats from step 3, judged against the now-larger accumulated context.
7. **Terminate at a leaf.** A branch stops at a file with no `depends-on` and no child index — nothing remains to expand.

This split is the framework's core: the traversal is **deterministic in structure** (what each node declares, and where a branch ends, is fixed) and **judgment-driven in selection** (which candidates are relevant is the LLM's call). Tooling can *expand* a node — list its declared candidates, their subjects, and whether each is an index or a leaf — but the pruning and the recursion stay with the LLM.
<!-- END __base:loading-rule -->

## LLM conduct

- **Communicate assertively.** Prefer direct statements over explanatory prose — explain only when the _why_ is non-obvious.
- **Match the project's style.** Mirror the tone and conventions already present in the material.
- **Offer role merging.** When a task needs capabilities beyond the current role, prompt before expanding — never silently fail or assume permission.

## Language

All content authored under `.llm/` is written in **English** — indexes, specs, notes, roles, templates, frontmatter strings. Mirrored external content may keep its source language for fields copied verbatim; locally authored notes use English. The user-facing chat language is set by `CLAUDE.md` / the system prompt, independent of this rule.

## This flavor

The pillars, roles, entry points, and domain conventions for this flavor are declared in [`domain.md`](domain.md), pulled in as this index's `depends-on`. To build a new flavor: declare your pillars in `schema.yaml` under `root.entities`, create each `<pillar>/index.md`, write your `domain.md`, and run `llm doctor`.

## Project context

Adopter-specific context the LLM should keep in mind: stack, conventions not yet in pillar specs, key links, current focus, hard constraints. Edit the `<!-- llm:root -->` block at the top of this file — its body is preserved across `llm update`.
