---
human_revised: false
version: 1
name: cumaru-specs
description: Use this skill whenever the user wants to grow or maintain the `specs/` pillar — bootstrap a new area, deepen an existing one, split into concerns/subareas, or consolidate a body that reads like a changelog. Trigger on phrases like "bootstrap the specs", "deepen the auth spec", "split this area into concerns", "consolidate specs/payments", or any task that frames the work as authoring or refactoring inside `specs/`. Skill is sdlc-light-only.
summary: Use this skill whenever the user wants to grow or maintain the `specs/` pillar — bootstrap a new area, deepen an existing one, split into concerns/subareas, or consolidate a body that reads like a changelog. Trigger on phrases like "bootstrap the specs", "deepen the auth spec", "split this area into concerns", "consolidate specs/payments", or any task that frames the work as authoring or refactoring inside `specs/`. Skill is sdlc-light-only.
---

# `cumaru-specs` — author and maintain `specs/`

The living-spec skill. Three recipes: **bootstrap** (initial scaffold), **deepen** (light → deep pass), **consolidate** (rewrite a changelog-shaped body as current state).

## Layout (recap from schema)

```
specs/
└── <area>/
    ├── index.md          ← [name!, summary!, depends-on!, relates, apps!]
    ├── <concern>.md      ← same frontmatter shape
    └── <subarea>/        ← nested area (recursive)
        └── index.md
```

**Contract:**
- **Living state**: every body reflects the system as it is now. There is no second store of absorbed work — this pillar *is* the record.
- **Bootstrap on demand**: an area is created the first time a plan declares it in `scope:`.
- **Admin-only authoring.**

## Recipe: bootstrap a spec area

1. **Read the project surface.** The active agent instructions, `README`, the directory of the area, and related entry points.
2. **Confirm with the user** before creating: name, summary, `depends-on:`, `apps:`.
3. `cumaru flow specs/<area> create`
4. `cumaru flow specs/<area>/index.md create`
5. Open `templates/spec.md`; author the frontmatter.
6. Body — follow the template: `## Overview`, `## Requirements (EARS / RFC 2119)`, `## Decisions`, `## Files`.
7. Optionally copy `templates/bootstrap.md` to `specs/<area>/bootstrap.md` for a discovery log.
8. run `cumaru tree specs --rows` .
9. `cumaru doctor`.

## Recipe: deepen an area

When a plan is about to touch an area and its spec is too thin:

1. Read `specs/<area>/index.md` end-to-end.
2. Read the code in the area's surface — sources, tests, configs.
3. Write EARS/RFC 2119 requirements grounded in code. Group under `## Requirements (EARS / RFC 2119)` subheaders.
4. **Split into a concern file** when a topic is large enough.
5. **Promote a concern to a subarea** when it has grown beyond a flat file.
6. Run `cumaru tree specs --rows` if the filesystem structure changed.
7. `cumaru doctor`.

## Recipe: consolidate an area (changelog → single coherent body)

Runs **on request**. There is no automatic trigger and no frontmatter state to
read: the signal is the body reading like a changelog instead of a flat
statement of what is true now.

1. Read the area's files.
2. When the history behind a passage is unclear, recover it from git:
   `git log --follow --oneline -- .cumaru/specs/<path>`.
3. **Rewrite the area's body into a single coherent spec.**
4. run `cumaru tree specs --rows`.
5. `cumaru doctor`.

## Spec absorption during absorb (NOT this skill)

When a plan closes via `cumaru-absorb`, the Admin:
1. Updates each spec area in the plan's `scope:` to reflect the new state.
3. Keeps the area's `summary:` accurate if its durable purpose changed.

This skill provides the recipes to **grow** the spec tree (bootstrap, deepen, consolidate). The `cumaru-absorb` skill provides the recipe to **absorb** a closed plan's delta into already-existing areas.

## What this skill does NOT do

- **Delta absorption** — `cumaru-absorb`.
- **Plan authoring** — `cumaru-plan`.

## Patterns

| User says | You do |
|---|---|
| "Bootstrap the specs" / "scaffold the spec areas" | Bootstrap recipe → propose area list → confirm → create each area |
| "Deepen the auth spec" | Deepen recipe on `specs/auth/` → light-or-deep read → write requirements → split/promote as needed |
| "Split this area into concerns" | Deepen recipe step 4 (split) or step 5 (promote) |
| "Consolidate specs/payments" | Consolidate recipe → read the body → recover history from git if needed → rewrite as current state |

Use `cumaru tree specs` for navigation; pair with `cumaru-plan` (scope paths) and `cumaru-absorb` (absorbs deltas).
