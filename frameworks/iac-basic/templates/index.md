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

Templates for the entity types in `.cumaru/`. Copy the relevant file when creating a new entity, then fill in the placeholders.

## Available templates

- [plan.md](plan.md) — `plans/<PLAN-ID>/index.md` — a changeset (Lead). Carries blast radius, rollback, promotion path.
- [task.md](task.md) — `plans/<PLAN-ID>/t<N>.md` — an apply step (Lead).
- [handoff.md](handoff.md) — `plans/<PLAN-ID>/handoff-t<N>.md` (Dev, durable hand-off per step).
- [delta-draft.md](delta-draft.md) — `plans/<PLAN-ID>/delta-draft.md` (Dev, proposed delta at change close).
- [delta.md](delta.md) — `archive/<PLAN-ID>/delta.md` (Lead, finalized during the archive flow).
- [topology.md](topology.md) — `topology/<area>/index.md` — a stack / topology area (Lead).
- [runbook.md](runbook.md) — `runbooks/<slug>/index.md` — a durable operational procedure (Lead).
- [exploration.md](exploration.md) — `exploring/<slug>/index.md` (Lead).
- [intake-ticket.md](intake-ticket.md) — `intake/<KEY>/index.md` (change / incident / task).
- [intake-story.md](intake-story.md) — `intake/<KEY>/index.md` (story; includes `## Coordination`).
- [intake-epic.md](intake-epic.md) — `intake/<KEY>/index.md` (epic).
- [any-index.md](any-index.md) — generic shape for any pillar's shallow `index.md`. Starting point for `intake/index.md`, `plans/index.md`, `archive/index.md`, `topology/index.md`, `exploring/index.md`, `runbooks/index.md`.
- [bootstrap.md](bootstrap.md) — `topology/<area>/bootstrap.md` (persistent discovery log used by the `cumaru-topology` skill's bootstrap + deepen recipes).
