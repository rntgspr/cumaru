---
human_revised: false
apps: [meta]
summary: Framework guidance for Specs and its required workflow.
---


# Specs

A pillar for the **living spec** of the system — what is true right now about product features, platform conventions, integrations, and durable decisions. Authored and refactored by the Admin; deltas are absorbed here on plan close.

## Rules

- **Living state.** The body of each `specs/<area>/index.md` (and its concern files) always reflects the current state of the system. There is no `## History` body section — historical wording can be found via `git log`.
- **`deltas:` frontmatter is the canonical reference.** Each spec area lists the plan IDs whose deltas built its current state.
- **Bootstrap on demand.** A spec area is created the first time a plan declares it in `scope:`. Don't seed empty areas in advance.
- **Concerns split inside an area.** A large area splits into per-concern files (`<area>/<concern>.md`) referenced from the area's `## Files` section. Tasks declare which concerns they touch in their frontmatter `concerns:`.
- **Subareas when needed.** When an area grows beyond a flat concern split, promote a concern into a nested subarea: `specs/<area>/<subarea>/index.md` with its own concerns.
- **Each area is a directory** with `index.md` (overview, requirements, decisions, files), any concern files, and optional subarea directories.

## Cross-reference discovery

Empty `depends-on:` and `relates:` do not prove that a concern is isolated. Use the filesystem tree as a bounded discovery surface before changing a shared behavior:

1. Run `cumaru tree specs/` to inspect top-level area summaries.
2. Choose the next relevant area from those summaries and the task subject. Run `cumaru tree specs/<area>/` or add `--deep` when the shallow result suggests nested concerns or subareas.
3. Repeat this exploration while newly surfaced `summary:` or `name:` values suggest another relevant concern.
4. Load only selected concern files. Before changing related source code, inspect their `reference` tables for affected files and consumers.
5. Report relevant consumers, spec updates outside the active `scope:`, and uncovered gaps in the spec tree.

## When to use

- A plan declares a path under `specs/` in its `scope:` → load the area's `index.md` and the concerns referenced by the active task.
- A task declares `concerns: [<name>, ...]` → load `specs/<area>/<concern>.md` for each.
- Tracing why a behavior is the way it is → follow the area's `deltas:` list back to the plans that built it.
- Bootstrapping a new area when planning work that touches an undocumented part of the system (Admin).

## When NOT to use

- Active work in progress → `plans/<PLAN-ID>/`.
- Pre-plan ideation or open questions → `exploring/<slug>/`.
