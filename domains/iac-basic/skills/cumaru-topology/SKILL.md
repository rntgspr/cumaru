---
human_revised: false
version: 1
name: cumaru-topology
description: Use this skill whenever the user wants to grow or maintain the `topology/` pillar — bootstrap a new stack/area, deepen an existing one, split into concerns/subareas (per provider/account/region), or consolidate after many deltas. Trigger on phrases like "bootstrap the topology", "scaffold the stacks", "document the networking stack", "deepen the data topology", "split this stack into concerns", "consolidate topology/networking", "compactar a área X", "this stack is too thin to plan a change against", or any task framed as authoring/refactoring inside `topology/`. Knows the pillar's recursive shape (`area` nesting `concern` or child `area`s), the `deltas:` ↔ `consolidated-at:` state model, and the Lead-only authoring contract.
summary: Use this skill whenever the user wants to grow or maintain the `topology/` pillar — bootstrap a new stack/area, deepen an existing one, split into concerns/subareas (per provider/account/region), or consolidate after many deltas. Trigger on phrases like "bootstrap the topology", "scaffold the stacks", "document the networking stack", "deepen the data topology", "split this stack into concerns", "consolidate topology/networking", "compactar a área X", "this stack is too thin to plan a change against", or any task framed as authoring/refactoring inside `topology/`. Knows the pillar's recursive shape (`area` nesting `concern` or child `area`s), the `deltas:` ↔ `consolidated-at:` state model, and the Lead-only authoring contract.
---

# `cumaru-topology` — author and maintain `topology/`

The living-topology skill. Three recipes that grow the `topology/` tree over a project's lifetime: **bootstrap** (initial scaffold of a stack/area), **deepen** (light → deep pass), **consolidate** (compact accumulated deltas). `topology/` is the durable truth of the infrastructure — what it is and how it connects — **never a copy of the HCL/manifest** (that is the executable spec; it drifts and lies).

## Layout (recap from schema)

```
topology/
└── <area>/                  ← a stack, or a logical grouping of stacks
    ├── index.md             ← [name!, summary!, depends-on!, relates, apps!, deltas, consolidated-at]
    ├── <concern>.md         ← same frontmatter shape — a per-topic file (networking, iam, …)
    └── <subarea>/           ← nested area (recursive — per provider/account/region)
        └── index.md
```

**Contract:**
- **Living state**: every body reflects the infrastructure as it is now. History lives in `archive/<PLAN-ID>/delta.md`.
- **`depends-on:` is the apply order** — the stacks that must be provisioned first (and whose outputs this one consumes). It is both the strongest load signal AND the apply sequence. `relates:` is soft ("consider").
- **`deltas:` is the canonical reference** — the change IDs whose deltas built the current state. Drill into `archive/` for verbose wording.
- **Bootstrap on demand**: an area is created the first time a changeset declares it in `scope:` — don't seed empty areas.
- **Lead-only authoring**: the Dev never writes inside `topology/` directly. Absorption happens during the Lead's archive flow (`cumaru-archive`), driven by the Dev's `delta-draft.md`.

## Recipe: bootstrap a stack/area

When the user agrees on a new area `<area>` (initial install, or the first change to a yet-undocumented stack):

1. **Read the real surface.** The stack's code dir (`*.tf` / module / Helm chart / manifests), its variables/outputs, `.agents/AGENTS.md`, and `README`. Goal is breadth: what it provisions, what it exposes, what it needs.
2. **Confirm with the user** before creating: name, summary, `depends-on:` (the stacks provisioned first whose outputs this consumes), `relates:`, `apps:` (the environments it runs in, from `meta.apps.values`).
3. `cumaru flow topology/<area> create`
4. `cumaru flow topology/<area>/index.md create`
5. Open `templates/topology.md`; author the frontmatter (`name`, `summary`, `depends-on` = apply-order prerequisites, `relates`, `apps`, `deltas: []`).
6. Body — follow the template:
   - `## Overview` — what the stack provisions, the **tool** that owns it, where the code lives. **No HCL/manifest paste.**
   - `## Interface` — Inputs (variables/secrets consumed, and from where) and Outputs (what downstream stacks consume).
   - `## Dependencies (apply order)` — why each `depends-on` is required.
   - `## Decisions` — non-obvious choices (provider/region/sizing/topology) or `(none surfaced)`.
   - `## Cost & security` — cost drivers, trust boundaries, IAM/secrets posture, blast-radius constraints.
   - `## Files` — each `<concern>.md` / `<subarea>/` with a one-line role.
7. **Optional discovery log** for large stacks: copy `templates/bootstrap.md` to `topology/<area>/bootstrap.md`, fill `## Discovery (light pass <ISO>)`. Leave on disk; deep passes append below.
8. Run `cumaru tree topology --rows` and verify the area summary.
9. `cumaru doctor` — navigation and summary checks clean.

**What NOT to do:** don't auto-create areas without confirmation (a bad split poisons every later change); don't paste the code into the spec; don't invent connectivity the code doesn't have.

## Recipe: deepen an area

When a change is about to touch a stack and its topology is too thin to plan against:

1. Read `topology/<area>/index.md` end-to-end (and any prior `bootstrap.md`).
2. Read the stack code by **topic** — networking has "VPC/CIDR", "subnets", "routing", "peering"; take notes with file refs.
3. For each topic, document Interface / Dependencies / Decisions grounded in code you can point to. Update `## Cost & security` as the posture becomes clear.
4. **Split into a concern file** when a topic deserves its own file (`cumaru flow topology/<area>/<concern>.md create`; copy the frontmatter shape; move the topic's content; link it under `## Files`).
5. **Promote a concern to a subarea** when it grows its own internal concerns — typically **per provider / account / region** (`cumaru flow topology/<area>/<subarea> create` + its `index.md`; move content; spawn child concerns). Subareas follow the same shape recursively.
6. **Append to the discovery log** if used (`## Discovery (deep pass <ISO>) — <scope>` at the end; don't edit prior sections).
7. run `cumaru tree topology --rows`. `cumaru doctor`.

**What NOT to do:** split when *conceptually* separable, not when typographically long; don't load every related stack into `depends-on:` — only the apply-order prerequisites; soft links go in `relates:`.

## Recipe: consolidate an area

When `deltas:` has grown long (≥5) and the per-change history makes the topology hard to read as "what's true now":

1. Read the area's `index.md` + concern/subarea files.
2. For each plan ID in `deltas:`, read `archive/<PLAN-ID>/delta.md` (the chronological changes).
3. **Rewrite the body into a single coherent topology.** Integrate every delta as if always present; where two contradict, reflect the **current** state.
4. Replace `deltas: [...]` with `consolidated-at: <today's ISO date>`. Keep `archive/<PLAN-ID>/` on disk (verbose history).
5. run `cumaru tree topology --rows`. `cumaru doctor`.

**What NOT to do:** don't delete archive entries; don't consolidate halfway; don't consolidate on every change close — pay the cost only when the weight is real.

## Not Requirements Language

Unlike behavioral specs, a topology area does **not** carry `## Requirements (EARS / RFC 2119)` — infrastructure is described by structure (interface, dependencies, decisions), not requirement bullets. EARS / RFC 2119 belongs in change-request acceptance criteria (`intake/`, slug-based plans).

## What this skill does NOT do

- **Delta absorption** — `cumaru-archive` (merges a closed changeset's delta into existing areas).
- **Changeset authoring** — `cumaru-plan` (declares the `scope:` paths this skill creates/maintains).
- **Drawing the graph** — `cumaru-arch` (renders the `depends-on`/`relates` edges as a diagram).

## Patterns

| User says | You do |
|---|---|
| "Bootstrap the topology" / "scaffold the stacks" | Bootstrap recipe → propose area list from code/README → confirm → create each |
| "Document the networking stack" / "deepen topology/data" | Deepen recipe → read stack code → interface/deps/decisions by topic → split/promote |
| "Split this stack per account" / "promote networking/peering to a subarea" | Deepen recipe step 4 (split) or 5 (promote) |
| "Consolidate topology/networking" | Consolidate recipe → read deltas → rewrite → swap `deltas` for `consolidated-at` |

Use `cumaru tag get/set` (CLI) for the `topology/index.md` round-trip; pair with `cumaru-plan` (`scope:`), `cumaru-archive` (absorb), `cumaru-arch` (draw), and `cumaru-doctor`.
