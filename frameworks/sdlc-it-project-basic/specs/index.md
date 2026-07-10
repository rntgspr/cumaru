---
human_revised: false
generated: true
generated-at: 2026-05-01T00:00:00Z
apps: [meta]
---

<!-- cumaru:specs -->
| Link | Description |
|------|-------------|

_No areas yet. Bootstrap a `specs/<area>/` directory the first time a plan touches it. Each row links to `specs/<area>/index.md` with a one-line description (what the area covers, key dependencies)._
<!-- /cumaru:specs -->

<!-- cumaru:absorptions -->
| SHA | KEY | Description |
|-----|-----|-------------|

_No absorbed plans yet. Each row records the commit SHA that absorbed a plan delta into specs, the plan key, and a one-line summary of what became durable._
<!-- /cumaru:absorptions -->

# Specs

A pillar for the **living spec** of the system — what is true right now about product features, platform conventions, integrations, and durable decisions. Authored and refactored by the Lead; deltas are absorbed here on plan close.

## Rules

- **Living state.** The body of each `specs/<area>/index.md` (and its concern files) always reflects the current state of the system. There is no `## History` body section; absorbed work is summarized in the `absorptions` table above.
- **`deltas:` frontmatter is the local trace.** Each spec area lists the plan IDs whose deltas built its current state. The durable cross-spec ledger is `cumaru:absorptions` on this index.
- **Bootstrap on demand.** A spec area is created the first time a plan declares it in `scope:`. Don't seed empty areas in advance.
- **Concerns split inside an area.** A large area splits into per-concern files (`<area>/<concern>.md`) referenced from the area's `## Files` section. Tasks declare which concerns they touch in their frontmatter `concerns:`.
- **Subareas when needed.** When an area grows beyond a flat concern split, promote a concern into a nested subarea: `specs/<area>/<subarea>/index.md` with its own concerns. Subareas follow the same shape as areas recursively. The parent area's `## Files` lists the subarea directories alongside any flat concern files.
- **Per-component split via `<component>.md`** files appears only when content meaningfully diverges between components. Otherwise the area's `index.md` carries everything.
- **Authoring is the Lead's.** Dev never writes inside `specs/` directly — spec absorption happens during the Lead's archive flow, driven by the Dev's `delta-draft.md`.
- **Each area is a directory** with `index.md` (overview, requirements, decisions, files), any concern files, and optional subarea directories.

## When to use

- A plan declares a path under `specs/` in its `scope:` → load the area's `index.md` and the concerns referenced by the active task.
- A task declares `concerns: [<name>, ...]` → load `specs/<area>/<concern>.md` for each.
- Tracing why a behavior is the way it is → follow the area's `deltas:` list, then find the corresponding KEY in `cumaru:absorptions` and inspect the SHA.
- Bootstrapping a new area when planning work that touches an undocumented part of the system (Lead).

## When NOT to use

- Active work in progress → `plans/<PLAN-ID>/`.
- Pre-plan ideation or open questions → `exploring/<slug>/`.
- Closed-plan staging details → `archive/<PLAN-ID>/` only while absorption is in flight.
- Mirror of tracker items → `intake/`.
