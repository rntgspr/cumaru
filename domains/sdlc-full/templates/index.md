---
human_revised: false
apps: [meta]
summary: Framework guidance for Templates and its required workflow.
---


# Templates

Templates for the various entity types in `.cumaru/`. Copy the relevant file when creating a new entity, then fill in the placeholders.

## Available templates

- [plan.md](plan.md) — `plans/<PLAN-ID>/index.md` (Lead)
- [task.md](task.md) — `plans/<PLAN-ID>/t<N>.md` (Lead)
- [handoff.md](handoff.md) — `plans/<PLAN-ID>/handoff-t<N>.md` (Dev, durable hand-off per task)
- [delta-draft.md](delta-draft.md) — `plans/<PLAN-ID>/delta-draft.md` (Dev, proposed delta at plan close)
- [delta.md](delta.md) — `archive/<PLAN-ID>/delta.md` (Lead, finalized from the Dev's draft during archive flow)
- [spec.md](spec.md) — `specs/<area>/index.md` (Lead)
- [exploration.md](exploration.md) — `exploring/<slug>/index.md` (Lead)
- [intake-ticket.md](intake-ticket.md) — `intake/<KEY>.md` (task / bug / spike)
- [intake-story.md](intake-story.md) — `intake/<KEY>.md` (story; includes `## Coordination` section)
- [intake-epic.md](intake-epic.md) — `intake/<KEY>.md` (epic)
- [any-index.md](any-index.md) — generic shape for any pillar's shallow `index.md` (header + table + Rules + When to use / NOT use). Use as the starting point for `intake/index.md`, `plans/index.md`, `archive/index.md`, `specs/index.md`, `exploring/index.md`.
- [bootstrap.md](bootstrap.md) — `specs/<area>/bootstrap.md` (persistent discovery log used by the `cumaru-specs` skill's bootstrap + deepen recipes). Carries the BOOTSTRAP-INSTRUCTIONS block plus the per-pass `## Discovery` sections.
