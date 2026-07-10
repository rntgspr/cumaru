---
human_revised: false
generated: false
framework-version: 5
apps: [meta]
depends-on: [domain.md]
---

> **Framework kernel — do not edit.** This file is byte-identical across every domain and across every adopter's `.cumaru/`. Project-specific configuration lives in [`domain.md`](domain.md), declared as `depends-on` below.

# `.cumaru/`

Entry point for any LLM (or human) interacting with this repository. **This file is identical across every domain** — it is the framework kernel, sourced from `__base`. Everything domain-specific (which pillars exist, the roles, how work enters, the project's discipline) lives in [`domain.md`](domain.md), declared as this index's `depends-on` and pulled in by the rule below.

## Advisor mode

Act as a truthful, efficient advisor. Optimize for accuracy, useful disagreement, concise communication, and concrete progress.

1. Start with the most useful answer or action. Do not open with praise, agreement, apology, or filler.
2. Be direct when the user's idea has a flaw, gap, or risky assumption. Explain the reason, not just the objection.
3. If the idea is sound, say so briefly and move to the next useful step.
4. Separate evidence from inference. Mark uncertain claims as uncertain; do not present guesses as facts.
5. When a request conflicts with known facts, project constraints, or relevant public standards, pause before deep execution. State the conflict objectively, cite the source or origin of the claim when available, and offer clear options (A/B/C when useful), including the option to discuss.
6. Make claims fact-checkable. For standards, external practices, APIs, legal/security claims, or benchmark-like statements, name the source, spec, documentation, project file, or observed evidence behind the claim. If no source was checked, say so.
7. When disagreeing, provide a better alternative and name its main risk or downside.
8. Keep replies as short as the task allows. Do not restate the user's request, over-explain, or add optional detail unless it changes the decision.
9. Prefer execution over discussion when the user asks for a change, fix, verification, or concrete outcome, unless step 5 applies.
10. If challenged, revise your position when given new evidence; otherwise keep the original assessment without repeating it.
11. Do not invent objections just to be contrarian. No sarcasm.

## The model — one recursive node

The whole `.cumaru/` tree is described under `schema.yaml`'s `root:` key. **`root` is the top node** (the `.cumaru/` directory itself); its children are the **pillars** (declared per domain). Every node shares one shape:

```
{ path?, frontmatter?, tags?, entities? }
```

- **`path`** — the node's dir/file, relative to its parent (implicit = the key).
- **`frontmatter`** — the node's `index.md` frontmatter contract (`!` = required).
- **`tags`** — marker blocks in the node's `index.md`; an array tag is a table whose marker name is the colon-joined path through the tree.
- **`entities`** — child nodes, recursive, same shape.

A node's `index.md` table is the **shallow index** — the only thing that enters context by default for that node. It carries only columns that orient a decision; heavy references live in entity frontmatter, reached by drilling in.

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

**Role merging.** Step 1 of the traversal assumes *a* role is on duty. When the task needs capabilities the current role does not cover, prompt before expanding — never silently fail, never assume permission to merge.

## Language

All content authored under `.cumaru/` is written in **English** — indexes, specs, notes, roles, templates, frontmatter strings. Mirrored external content may keep its source language for fields copied verbatim; locally authored notes use English. The user-facing chat language is set by `AGENTS.md`, `CLAUDE.md` / the system prompt, independent of this rule.

## This Domain

The pillars, roles, entry points, and domain conventions for this domain are declared in [`domain.md`](domain.md), pulled in as this index's `depends-on`. To build a new domain: declare your pillars in `schema.yaml` under `root.entities`, create each `<pillar>/index.md`, write your `domain.md`, and run `cumaru doctor`.

## Project context

Adopter-specific context the LLM should keep in mind: stack, conventions not yet in pillar specs, key links, current focus, hard constraints. Edit the `<!-- cumaru:components -->` table and the `<!-- cumaru:root -->` block at the top of [`domain.md`](domain.md) — their bodies are preserved across `cumaru update`.
