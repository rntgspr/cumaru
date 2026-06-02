---
human_revised: false
version: 1
name: cumaru-specs
description: Use this skill whenever the user wants to grow or maintain the `specs/` pillar — bootstrap a new area, deepen an existing one, split into concerns/subareas, or consolidate after many deltas. Trigger on phrases like "bootstrap the specs", "deepen the auth spec", "split this area into concerns", "consolidate specs/payments", or any task that frames the work as authoring or refactoring inside `specs/`. Skill is sdlc-light-only.
---

# `cumaru-specs` — author and maintain `specs/`

The living-spec skill. Three recipes: **bootstrap** (initial scaffold), **deepen** (light → deep pass), **consolidate** (compact accumulated deltas).

## Layout (recap from schema)

```
specs/
└── <area>/
    ├── index.md          ← [name!, summary!, depends-on!, relates, apps!, deltas, consolidated-at]
    ├── <concern>.md      ← same frontmatter shape
    └── <subarea>/        ← nested area (recursive)
        └── index.md
```

**Contract:**
- **Living state**: every body reflects the system as it is now. History references via `deltas:` pointing to `plans/<ID>/`.
- **`deltas:` is the canonical reference** — list of plan IDs whose deltas built the current state.
- **Bootstrap on demand**: an area is created the first time a plan declares it in `scope:`.
- **Admin-only authoring.**

## Recipe: bootstrap a spec area

1. **Read the project surface.** `CLAUDE.md`, `README`, the directory of the area, related entry-points.
2. **Confirm with the user** before creating: name, summary, `depends-on:`, `apps:`.
3. `cumaru flow specs/<area> create`
4. `cumaru flow specs/<area>/index.md create`
5. Open `templates/spec.md`; author the frontmatter.
6. Body — follow the template: `## Overview`, `## Requirements (EARS)`, `## Decisions`, `## Files`.
7. Optionally copy `templates/bootstrap.md` to `specs/<area>/bootstrap.md` for a discovery log.
8. Re-emit `specs/index.md` row via `cumaru tag set specs/index.md specs <new body>`.
9. `cumaru doctor`.

## Recipe: deepen an area

When a plan is about to touch an area and its spec is too thin:

1. Read `specs/<area>/index.md` end-to-end.
2. Read the code in the area's surface — sources, tests, configs.
3. Write EARS-style requirements grounded in code. Group under `## Requirements (EARS)` subheaders.
4. **Split into a concern file** when a topic is large enough.
5. **Promote a concern to a subarea** when it has grown beyond a flat file.
6. Re-emit `specs/index.md` if new rows appeared.
7. `cumaru doctor`.

## Recipe: consolidate an area (deltas → single coherent body)

When an area's `deltas:` list has grown long (≥5 entries):

1. Read the area's files.
2. For each plan ID in `deltas:`, trace the changes via git or by revisiting the plan's intent.
3. **Rewrite the area's body into a single coherent spec.**
4. Replace `deltas: [...]` with `consolidated-at: <today's ISO date>`.
5. Re-emit `specs/index.md` row.
6. `cumaru doctor`.

## Spec absorption during absorb (NOT this skill)

When a plan closes via `cumaru-absorb`, the Admin:
1. Updates each spec area in the plan's `scope:` to reflect the new state.
2. Appends the plan `<PLAN-ID>` to each area's `deltas:` frontmatter.
3. Re-emits the area's row in `specs/index.md`.

This skill provides the recipes to **grow** the spec tree (bootstrap, deepen, consolidate). The `cumaru-absorb` skill provides the recipe to **absorb** a closed plan's delta into already-existing areas.

## What this skill does NOT do

- **Delta absorption** — `cumaru-absorb`.
- **Plan authoring** — `cumaru-plan`.

## Patterns

| User says | You do |
|---|---|
| "Bootstrap the specs" / "scaffold the spec areas" | Bootstrap recipe → propose area list → confirm → create each area |
| "Deepen the auth spec" | Deepen recipe on `specs/auth/` → light-or-deep read → write EARS → split/promote as needed |
| "Split this area into concerns" | Deepen recipe step 4 (split) or step 5 (promote) |
| "Consolidate specs/payments" | Consolidate recipe → read deltas → rewrite body → swap `deltas` for `consolidated-at` |

Use `cumaru tag get/set` (CLI, no skill) for `specs/index.md` table round-trip; pair with `cumaru-plan` (scope paths) and `cumaru-absorb` (absorbs deltas).
