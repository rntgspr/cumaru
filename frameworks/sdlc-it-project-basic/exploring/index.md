---
human_revised: false
generated: true
generated-at: 2026-05-07T00:00:00Z
apps: [meta]
---

<!-- cumaru:exploring -->
| Link | Description |
|------|-------------|

_No explorations yet. Each row links to `exploring/<slug>/index.md` with a one-line description of the idea._
<!-- /cumaru:exploring -->

# Exploring

Incubator for ideas that are **not yet plans**. Free-form notes the user wants to think about, sketch, or argue with before committing. An exploration has no tracker item and no commitment — it either matures into a plan or gets dropped. This file is the only entry point: drilling into a specific `<slug>/` requires explicit instruction.

## What goes in

Loose ideas worth capturing before they lose shape — a refactor someone might attempt, a feature hypothesis, an architecture sketch, a decision-in-progress with pros/cons to revisit. Anything too premature to justify a `plans/maintenance-<slug>/` directory but worth keeping around.

### When to use

- Capturing a recurring thought before it scatters.
- Sketching a refactor or architecture change before it's ready for spec/plan.
- Preserving an analysis or comparison the user asked for that isn't tied to a ticket.
- Storing decisions-in-progress (with pros/cons) to revisit later.

### When **not** to use

- Anything with acceptance criteria → `plans/`.
- Anything that describes the system as it is → `specs/`.
- Anything already done → `archive/`.

## Structure

```
exploring/<slug>/
├── index.md          ← required; same frontmatter contract as any entity
└── *.md              ← optional aux (referenced via `aux:` only)
```

`<slug>` is **pure kebab-case** — no `maintenance-` prefix, no tracker key. An exploration is **not** a plan: no `scope:`, no DAG, no EARS / RFC 2119 criteria required. The body is free-form.

## Lifecycle of an exploration

An exploration is **transient by design** — it should eventually either become a plan or be discarded. Two valid exits:

- **Promote** — the idea matured into committed work. The Lead moves the directory to `plans/maintenance-<slug>/` (or `plans/<KEY>/` when a tracker item lands for it), authors the plan-level frontmatter the exploration didn't have (`scope:`, EARS / RFC 2119 criteria, DAG), and removes the entry from `exploring/`.
- **Drop** — the idea won't happen. The Lead deletes the directory. Explorations never migrate to `archive/`; only completed plans do.

Stale entries are a smell: prune or promote, don't accumulate.

## Loading and ownership

This file is the only opportunistic entry point — drilling into `<slug>/` requires explicit instruction (see the Loading rule in the root `.cumaru/index.md`). The Lead owns `exploring/`: captures, prunes, and promotes. Dev and Ghost do not write here.
