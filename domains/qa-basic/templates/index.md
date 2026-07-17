---
human_revised: false
apps: [meta]
summary: Framework guidance for Templates and its required workflow.
---


# Templates

Templates for the entity types in `.cumaru/`. Copy the relevant file when creating a new entity, then fill in the placeholders.

## Available templates

- [plan.md](plan.md) — `plans/<PLAN-ID>/index.md` — a test campaign (Lead). Carries test strategy, scope, risks/gaps.
- [task.md](task.md) — `plans/<PLAN-ID>/t<N>.md` — a case to author/automate at a level (Lead).
- [handoff.md](handoff.md) — `plans/<PLAN-ID>/handoff-t<N>.md` (Dev, durable hand-off per case).
- [delta-draft.md](delta-draft.md) — `plans/<PLAN-ID>/delta-draft.md` (Dev, proposed coverage delta at campaign close).
- [delta.md](delta.md) — `archive/<PLAN-ID>/delta.md` (Lead, finalized during the archive flow).
- [coverage.md](coverage.md) — `coverage/<area>/index.md` — a coverage area: levels, `## Scenarios (GWT)`, gaps (Lead).
- [standard.md](standard.md) — `standards/<slug>/index.md` — a durable testing convention (Lead).
- [exploration.md](exploration.md) — `exploring/<slug>/index.md` — an exploratory-testing charter (Lead).
- [intake-ticket.md](intake-ticket.md) — `intake/<KEY>/index.md` (feature / bug / regression / spike).
- [intake-story.md](intake-story.md) — `intake/<KEY>/index.md` (story; includes `## Coordination`).
- [intake-epic.md](intake-epic.md) — `intake/<KEY>/index.md` (epic).
- [any-index.md](any-index.md) — generic shape for any pillar's shallow `index.md`. Starting point for `intake/index.md`, `plans/index.md`, `archive/index.md`, `coverage/index.md`, `exploring/index.md`, `standards/index.md`.
- [bootstrap.md](bootstrap.md) — `coverage/<area>/bootstrap.md` (persistent discovery log used by the `cumaru-coverage` skill's bootstrap + deep recipes).
