---
human_revised: false
generated: true
generated-at: 2026-05-01T00:00:00Z
count: 0
apps: [meta]
---

# Exploring

A pillar for **ideas in incubation** — anything you want to think about, sketch, or argue with yourself before committing to a plan.

| Idea | Status | Apps | Updated | Summary |
|------|--------|------|---------|---------|
<!-- llm:entries:exploring -->
<!-- /llm:entries:exploring -->

_No explorations yet._

## Rules

- **No Jira tickets here.** If a topic is mature enough to map to Jira, it goes to `intake/` and `plans/`. Exploring is pre-plan.
- **No `maintenance-` prefix.** Slug is the slug. Add a slug-only directory (e.g. `exploring/feature-flag-naming-strategy/`).
- **Never loaded by default.** Same rule as `archive/`. The Lead consults `exploring/index.md` (this file) when looking for prior thoughts; drills into a specific idea only when explicitly asked.
- **Each idea is a directory** with `index.md` and optional aux files. Same universal entity rules.
- **Promotion path:** when an idea matures, the Lead either:
  - Moves it to `plans/maintenance-<slug>/` (internal initiative), or
  - Moves it to `plans/<JIRA-ID>/` after creating the Jira ticket from the idea.
- **Drop path:** ideas that won't happen are simply deleted. Git keeps the history. Do not accumulate dead ideas.

## When to use

- Capturing a recurring thought before it scatters.
- Sketching a refactor or architecture change before it's ready for spec/plan.
- Preserving an analysis or comparison the user asked for that isn't tied to a ticket.
- Storing decisions-in-progress (with pros/cons) to revisit later.

## When NOT to use

- Anything with acceptance criteria → `plans/`.
- Anything that describes the system as it is → `specs/`.
- Anything already done → `archive/`.
