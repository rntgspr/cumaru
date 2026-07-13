---
human_revised: false
generated: false
apps: [meta]
---

<!-- cumaru:templates -->
| Link | Description |
|------|-------------|

_No custom templates yet._
<!-- /cumaru:templates -->

# Templates

Templates for the various entity types in `.cumaru/`. Copy the relevant file when creating a new entity, then fill in the placeholders.

## Available templates

- [plan.md](plan.md) — `plans/<PLAN-ID>/index.md` (Lead)
- [task.md](task.md) — `plans/<PLAN-ID>/t<N>.md` (Lead)
- [handoff.md](handoff.md) — `plans/<PLAN-ID>/handoff-t<N>.md` (Dev, durable hand-off per task)
- [delta-draft.md](delta-draft.md) — `plans/<PLAN-ID>/delta-draft.md` (Dev, proposed delta at plan close)
- [spec.md](spec.md) — `specs/<area>/index.md` (Lead)
- [exploration.md](exploration.md) — `exploring/<slug>/index.md` (Lead)
- [any-index.md](any-index.md) — generic shape for any pillar's shallow `index.md` (header + table + Rules + When to use / NOT use). Use as the starting point for `plans/index.md`, `specs/index.md`, `exploring/index.md`.
- [bootstrap.md](bootstrap.md) — `specs/<area>/bootstrap.md` (persistent discovery log used by the `cumaru-specs` skill's bootstrap + deepen recipes). Carries the BOOTSTRAP-INSTRUCTIONS block plus the per-pass `## Discovery` sections.
