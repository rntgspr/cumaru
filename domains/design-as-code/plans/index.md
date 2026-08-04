---
human_revised: false
targets: [meta]
summary: Framework guidance for Plans and its required workflow.
---


# Plans

A pillar for **active design delivery plans**; tracker briefs live in `intake/`. One directory per item or initiative. The Design Lead authors `index.md` and `t<N>.md` at planning time; Designer executes bounded tasks and returns handoffs; Reviewer independently evaluates the delivery. Design Lead reconciles findings before absorbing the delta into `specs/`.

## Rules

- **One directory per plan.** `plans/<KEY>/` for tracker-backed work, `plans/maintenance-<slug>/` for internal initiatives. The directory name is the plan ID.
- **Slug-based plans require the `maintenance-` prefix.** Pure kebab-case slug (`maintenance-cleanup-deprecated-helpers`). No `key:` frontmatter field.
- **Follow `templates/plan.md`.** Tracker-backed Overview and Acceptance Criteria live only in `intake/<KEY>.md`; maintenance keeps them in its plan. Coverage maps criterion IDs to tasks without repeating requirements.
- **Tasks within a plan may run in parallel** when `depends-on:` is satisfied and allowed writes do not overlap; `files:` predictions alone do not grant permission.
- **Each entry is a directory** with `index.md`, `t<N>.md` per task, `handoff-t<N>.md` for each completed task, and `delta-draft.md` at close.

Completed plans are removed after verified direct absorption with `cumaru-absorb`;
retain related evidence only while other active work still needs it.

## When to use

- Starting work on a tracker item or internal initiative → create `plans/<PLAN-ID>/` (Design Lead).
- Executing an active task → Designer writes `handoff-t<N>.md`; Lead reconciles task status and the plan DAG from the evidence.
- Closing a plan → Design Lead applies the review and readiness gate in `roles/lead.md`, then follows `cumaru-absorb`.

## When NOT to use

- Description of the system as it is today → `specs/<area>/`.
- Pre-plan ideation, sketches, options analysis → `concepts/<slug>/`.
