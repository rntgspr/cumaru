---
human_revised: false
generated: true
generated-at: 2026-05-01T00:00:00Z
apps: [meta]
---

<!-- cumaru:plans -->
| Link | Description |
|------|-------------|

_No active plans yet. Each row links to `plans/<PLAN-ID>/index.md` with a one-line description (title, task count, scope hint)._
<!-- /cumaru:plans -->

# Plans

A pillar for **active execution plans** — one directory per item or internal initiative currently being worked on. Authored by the Lead at planning time; moved to `archive/` by the Lead on close.

## Rules

- **One directory per plan.** `plans/<KEY>/` for tracker-backed work (using the linked intake item's `<KEY>`), `plans/maintenance-<slug>/` for internal initiatives without a tracker item. The directory name is the plan ID.
- **Slug-based plans require the `maintenance-` prefix.** Pure kebab-case slug (`maintenance-cleanup-deprecated-helpers`). No `key:` frontmatter field.
- **Plan body for tracker-backed plans carries `## Plan / DAG`, `## Out of scope`, `## Risks` only.** Overview and Acceptance Criteria live in the linked `intake/<KEY>/index.md` and are not duplicated here. Slug-based plans keep both inside the plan body.
- **Stories are linear at the Lead level.** Only one plan from the same story is active at a time. Cross-ticket coordination happens in the story's `## Coordination` section under `intake/<STORY-KEY>/` (when the linked item is a story).
- **Tasks within a plan may run in parallel** when `depends-on:` is satisfied and `files:` predictions do not overlap. The Lead verifies before dispatch and reconciles cascades from `handoff-t<N>.md` during execution.
- **Authoring permissions:** the Lead authors `index.md` and `t<N>.md`. The Dev writes `handoff-t<N>.md` (per task) and `delta-draft.md` (at plan close) inside the same directory; the Lead consumes them.
- **Each entry is a directory** with `index.md`, `t<N>.md` per task, optional `handoff-t<N>.md`, and `delta-draft.md` at close.

## When to use

- Starting work on a tracker item → create `plans/<KEY>/` (Lead).
- Internal initiative without a tracker item → create `plans/maintenance-<slug>/` (Lead).
- Implementing tasks of an active plan → flip `t<N>.md` `status:` and write `handoff-t<N>.md` (Dev).
- Closing a plan → Dev writes `delta-draft.md`; Lead validates, finalizes into `archive/<PLAN-ID>/delta.md`, absorbs into specs, moves the plan.

## When NOT to use

- Item scope, Overview, or Acceptance Criteria → `intake/<KEY>/`.
- Description of the system as it is today → `specs/<area>/`.
- Pre-plan ideation, sketches, options analysis → `exploring/<slug>/`.
- Completed work → `archive/<PLAN-ID>/`.
