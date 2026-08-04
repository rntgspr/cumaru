---
human_revised: false
apps: [meta]
summary: Framework guidance for Specs and its required workflow.
---

# Specs

A pillar for the **living spec** of the system — what is true right now about product features, platform conventions, integrations, and durable decisions. Authored and refactored by the Lead; deltas are absorbed here on plan close.

## Rules

- **Living state.** The body of each `specs/<area>/index.md` (and its concern files) always reflects the current state of the system. There is no `## History` body section. Absorbed work is visible as the current state of the body itself; how it got there is `git log`'s job.
- **This pillar is the record.** There is no second store of absorbed work — no ledger, no per-area list of the plans that built it. `specs/` states what is true now, and that claim stands on its own.
- **Bootstrap on demand.** A spec area is created the first time a plan declares it in `scope:`. Don't seed empty areas in advance.
- **Concerns split inside an area.** A large area splits into per-concern files (`<area>/<concern>.md`) referenced from the area's `## Files` section. Tasks declare which concerns they touch in their frontmatter `concerns:`.
- **Subareas when needed.** When an area grows beyond a flat concern split, promote a concern into a nested subarea: `specs/<area>/<subarea>/index.md` with its own concerns. Subareas follow the same shape as areas recursively. The parent area's `## Files` lists the subarea directories alongside any flat concern files.
- **Per-component split via `<component>.md`** files appears only when content meaningfully diverges between components. Otherwise the area's `index.md` carries everything.
- **Authoring is the Lead's.** Dev never writes inside `specs/` directly — spec absorption happens during the Lead's archive flow, driven by the Dev's `delta-draft.md`.
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
- Tracing why a behavior is the way it is → read the relevant area, then use `git log` (see **History** below).
- Bootstrapping a new area when planning work that touches an undocumented part of the system (Lead).

## History

The pillar carries no history of its own. Git is the cross-reference, in both
directions:

```bash
# which spec files did this ticket change?
git log --all --grep=<KEY> --name-only -- .cumaru/specs/
# which tickets built this spec?
git log --follow --oneline -- .cumaru/specs/<path>
```

This makes the absorption commit **message** load-bearing: it must name every
KEY it absorbs. Messages survive rebase and squash; SHAs do not.

## When NOT to use

- Active work in progress → `plans/<PLAN-ID>/`.
- Pre-plan ideation or open questions → `exploring/<slug>/`.
- Open locally authored work item → `issues/<slug>/`.
- Closed-plan staging details → `archive/<PLAN-ID>/` only while absorption is in flight.
- Mirror of tracker items → `intake/`.
