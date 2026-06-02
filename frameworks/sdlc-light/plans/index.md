---
human_revised: false
generated: true
generated-at: 2026-07-02T00:00:00Z
apps: [meta]
---

<!-- cumaru:plans -->
| Link | Description |
|------|-------------|

_No plans yet. Each row links to `plans/<PLAN-ID>/index.md` with a one-line description (title, task count, scope hint)._
<!-- /cumaru:plans -->

# Plans

A pillar for **all work items** — intake, active execution plans, and completed work. One directory per item or initiative. The Admin authors `index.md` and `t<N>.md` at planning time; on close the Admin absorbs the delta into `specs/`.

## Rules

- **One directory per plan.** `plans/<KEY>/` for tracker-backed work, `plans/maintenance-<slug>/` for internal initiatives. The directory name is the plan ID.
- **Slug-based plans require the `maintenance-` prefix.** Pure kebab-case slug (`maintenance-cleanup-deprecated-helpers`). No `key:` frontmatter field.
- **Plan body carries `## Overview`, `## Acceptance Criteria (EARS)`, `## Plan / DAG`, `## Out of scope`, `## Risks`.** Unlike SDLC, there is no separate intake pillar — everything lives in the plan body.
- **Tasks within a plan may run in parallel** when `depends-on:` is satisfied and `files:` predictions do not overlap.
- **Each entry is a directory** with `index.md`, `t<N>.md` per task, optional `handoff-t<N>.md`, and `delta-draft.md` at close.

## When to use

- Starting work on a tracker item or internal initiative → create `plans/<PLAN-ID>/` (Admin).
- Implementing tasks of an active plan → flip `t<N>.md` `status:` and write `handoff-t<N>.md`.
- Closing a plan → Admin validates delta-draft, absorbs into specs, removes plan files.

## When NOT to use

- Description of the system as it is today → `specs/<area>/`.
- Pre-plan ideation, sketches, options analysis → `exploring/<slug>/`.
