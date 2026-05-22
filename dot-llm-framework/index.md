---
human_revised: false
generated: false
apps: [meta]
framework-version: 3
---

<!-- llm:components -->
| Key | Folder | Stack/Notes |
|-----|--------|-------------|
_(empty — replace with your components)_
<!-- /llm:components -->

<!-- llm:root -->
_(empty — replace with adopter-specific context, or delete this placeholder)_
<!-- /llm:root -->

# `.llm/`

Entry point for any LLM (or human) interacting with this repository.

> **Load only what is declared. Everything else stays on disk but out of context.**

`schema.yaml` is the canonical contract — read its header (`HOW TO READ THIS SCHEMA`) for the node shape, the `frontmatter`/`tags` conventions, and the value-type rules. This file is the **narrative**: how the tree is organized and how context flows. It does not repeat the schema.

> **Status (framework-version 3).** This document describes the v3 model: a single
> recursive node tree (`root`), a tracker-agnostic flat `intake`, and lean indexes.
> The starter `templates/`, the framework's own pillar `index.md` files, and the
> `llm` CLI (`regen`/`doctor`/`intake`/`sync`) may still reflect v2 — they are
> migrated in a later pass. To upgrade an existing project, follow the `llm-cli`
> skill's **v2 → v3 migration** section.

## The model — one recursive node

The whole `.llm/` tree is described under `schema.yaml`'s `root:` key. **`root` is the top node** (the `.llm/` directory itself); its children are the **pillars**. Every node — root and every descendant — shares one shape:

```
{ path?, frontmatter?, tags?, entities? }
```

- **`path`** — the node's dir/file, relative to its parent (implicit = the key).
- **`frontmatter`** — the node's `index.md` frontmatter contract (`!` = required).
- **`tags`** — marker blocks in the node's `index.md`. An array tag is a markdown table (its items are the columns); the marker name is the colon-joined path through the tree (`<!-- llm:plans:plan:handoff:files -->`).
- **`entities`** — child nodes, recursive, same shape — reflecting the files/dirs inside.

A node's `index.md` table (its `tags` entry) is the **shallow index** — the only thing that enters context by default for that node. It carries **only columns that orient a decision**; timestamps and heavy references live in the entity frontmatter and are reached by drilling in.

## The pillars (root's children)

```
.llm/
├── index.md      ← this file (root node: components + root blocks, framework-version)
├── schema.yaml   ← canonical contract
├── intake/       ← tracker-agnostic mirror of work items
├── plans/        ← active execution plans (each: a plan + its tasks/handoffs/delta-draft)
├── archive/      ← completed plans + their finalized deltas (never loaded by default)
├── specs/        ← living spec; areas nest subareas; the ground truth of the system
├── exploring/    ← pre-plan ideas in incubation (never loaded by default)
├── reviews/      ← optional review artifacts
├── roles/        ← agent roles (lead, dev, ghost)
└── templates/    ← entity templates
```

- **`intake/` — what is asked.** A flat mirror of work items, **tracker-agnostic**: each item lives at `intake/<KEY>/`, carries `key` + `type` (the tracker issuetype: epic, story, task, bug, …), and links to others via `relates` (many-to-many, **non-blocking**). No enforced hierarchy — a team that skips epics or stories simply never creates items of that type. The tracker (jira, linear, clickup, …) is named once by `tracker` on `intake/index.md`.
- **`plans/` — how we will do it.** One `plans/<PLAN-ID>/` per active plan. The plan's `index.md` declares `scope` (which `specs/` paths it touches) and links to intake via `key` (optional — slug-based `maintenance-<slug>` plans have none). Inside the plan dir, at the same level, live its `task`, `handoff`, and `delta_draft` files.
- **`archive/` — what we did.** Completed plans, moved here on close. An archived plan IS the plan's `index.md` (status forced to `done`, plus `completed-at`/`delta`), with its finalized `delta.md` beside it. Never loaded by default; drill in by reference only.
- **`specs/` — what is true now.** The living spec. Areas nest subareas to arbitrary depth. `depends-on` is a **hard, blocking** prerequisite (load it with the area); `relates` is a **soft** cross-link. On plan close, the plan's delta is absorbed into the spec body and the plan's `key` is appended to the area's `deltas` — until `specs consolidate` compacts them into a single `consolidated-at` date.
- **`exploring/` — pre-plan ideas.** `exploring/<slug>/` incubators with no commitment. Transient: an idea either matures into a plan or is dropped (terminal exits move/delete the dir). Never loaded by default.

## Loading rule

The LLM loads only what is **declared** — never what is physically near. Three sources declare: the active plan, the role on duty, explicit user instruction.

- **No plan active.** Load shallow indexes per role (see below). Indexes are *maps* of what exists — cheap tokens. Drilling into a node is a separate, deliberate step.
- **A plan is active.** It declares `scope:` (paths under `specs/`) and `aux:`; the linked intake item (`key`) and the scoped spec areas enter context — nothing else.
- **Tree-shaking specs.** An area's index row shows `Depends-on` (must load) and `Relates` (consider). Pull the required closure; weigh the related set before loading more.
- **Drill-into a referenced index.** When context references a node's index, inspect the entries it lists: a direct name/description match → load only that; no match → load all children (the relation may hide in a file whose name doesn't surface it).

| Role  | Shallow indexes loaded                                                     | Rationale |
|-------|----------------------------------------------------------------------------|-----------|
| Lead  | `plans/index.md`, `specs/index.md`, `intake/index.md`, `archive/index.md`  | Orchestrates — needs the full map to plan, dispatch, reference history. |
| Dev   | none                                                                       | Operates inside a dispatched `plans/<PLAN-ID>/`. No active plan → recommend switching to Lead. |
| Ghost | none                                                                       | Ad-hoc, read-only; pulls a shallow only when the question requires it. |

## Roles

- **Lead** — primary author of `.llm/`. Plans work, maintains specs, runs the archive flow on close, dispatches Dev sub-agents within a plan, owns `exploring/`.
- **Dev** — implements tasks inside the active plan. Bounded write access: own `t<N>.md` (`status`, `aux`, body), `handoff-t<N>.md` per task, and `delta-draft.md` at plan close. Never writes elsewhere in `.llm/`.
- **Ghost** — IDE-pair agent for ad-hoc help. Read-only by default; writes only when the user explicitly asks. Never writes inside `.llm/`.

`intake/` is a tracker mirror — syncing it is a **mechanical operation**, not a role responsibility. Roles only **read** intake.

## Language

All content authored under `.llm/` is written in **English** — indexes, plans, specs, deltas, reviews, roles, templates, and frontmatter strings. Mirrored tracker content in `intake/` may keep its source language for fields that come straight from the tracker; locally authored notes use English. The user-facing chat language is set by `CLAUDE.md` / the system prompt and is independent of this rule.

## Project context

Adopter-specific orientation the LLM should keep in mind: stack, monorepo layout, conventions not yet in `specs/`, external links, current focus, hard constraints. Edit the `<!-- llm:root -->` block at the **top of this file** — its body is preserved across `llm sync` upgrades. List your components in the `<!-- llm:components -->` table and mirror them under `meta.apps.values` in `schema.yaml`.
