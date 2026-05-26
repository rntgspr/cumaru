---
human_revised: false
name: llm-plan
description: Use this skill whenever the user wants to bootstrap, grow, or advance a plan in the project — open a new plan (tracker-backed or slug-based), add a task, write a handoff, draft the delta, or transition status. Trigger on phrases like "start a plan for JET-1234", "novo plano de manutenção", "add task T3", "write the handoff for T2", "draft the delta", "transition the plan to done", "this plan is ready to archive", or any task that frames the work as authoring inside `plans/`. Skill is sdlc-only — it knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the role split (Lead authors plan + tasks; Dev writes handoffs + delta-draft).
---

# `llm-plan` — author plans, tasks, handoffs, and the delta draft

The plan-lifecycle skill. Covers everything from bootstrap of a new `plans/<PLAN-ID>/` to readiness-for-archive. Archive itself lives in [`llm-archive`](../llm-archive/SKILL.md).

## Layout (recap from schema)

```
plans/<PLAN-ID>/
├── index.md          ← [scope!, status!, summary!, apps!, key, type, epic, story, aux]
├── t1.md             ← [plan!, task!, depends-on!, concerns!, files!, status!, apps!, aux!]
├── handoff-t1.md     ← [plan!, task!, status!, date!] + <!-- llm:files --> (path-list)
├── t2.md             ...
└── delta-draft.md    ← [plan!, status!, date!]  (status: always `draft`)
```

`<PLAN-ID>`:
- Tracker-backed → `<KEY>` (e.g. `JET-1234`). Requires `intake/<KEY>/` to exist.
- Slug-based → `maintenance-<kebab-slug>` (e.g. `maintenance-cleanup-deprecated-helpers`). No `key:` in frontmatter.

**Role split**:
- **Lead** authors `index.md` + each `t<N>.md`.
- **Dev** writes `handoff-t<N>.md` (after completing T<N>) and `delta-draft.md` (at plan close).

## Recipe: bootstrap a new plan (tracker-backed)

When the user says "start a plan for JET-1234" / "vamos começar JET-1234":

1. **Pre-check.** `intake/<KEY>/index.md` must exist. If not, run `llm intake <KEY>` first.
2. **Read the intake.** Overview + Acceptance Criteria live there — don't duplicate into the plan.
3. **Decide scope.** Propose the `specs/<area>[/<subarea>]/<concern>` paths this plan will touch. Read the intake + skim relevant `specs/` to suggest a list. **Confirm with the user.**
4. `llm flow plans/<KEY> create`
5. `llm flow plans/<KEY>/index.md create`
6. Open `templates/plan.md`; author the frontmatter:
   - `key: <KEY>`, `type:` (task | story | bug | spike from intake), optional `epic:`, `story:`.
   - `scope: [<list from step 3>]`.
   - `status: in-progress` (drafting is fine if you're still arguing scope; flip to in-progress when work starts).
   - `summary:` one-line (will appear in `plans/index.md`).
   - `apps: [...]` from intake's `apps:`.
7. Body — tracker-backed plans carry **only** `## Plan / DAG`, `## Out of scope`, `## Risks`. Overview + AC are in intake.
8. Skip task creation now if you don't yet know the breakdown; add them as the work clarifies (see "Recipe: add a task" below). Or seed `t1.md` with the first task immediately.
9. Re-emit `plans/index.md` row via `llm tag set plans/index.md plans <new body>` (columns: Key | Title | Tasks | Apps). `Tasks` is `done/total` (e.g. `0/3` or `0/0` if not seeded yet).
10. `llm doctor` — orphan check should be clean.

## Recipe: bootstrap a new plan (slug-based / maintenance)

When the user says "novo plano de manutenção <X>" / "internal refactor of Y, no ticket":

1. **Decide the slug.** Kebab-case, prefixed with `maintenance-`. Confirm.
2. `llm flow plans/maintenance-<slug> create`
3. `llm flow plans/maintenance-<slug>/index.md create`
4. Frontmatter — no `key:`, no `type:`, no `epic:`/`story:`. Required: `scope`, `status: in-progress`, `summary`, `apps`.
5. Body — slug-based plans carry **everything** (no intake to defer to): `## Overview` + `## Acceptance Criteria (EARS)` + `## Plan / DAG` + `## Out of scope` + `## Risks`.
6. Re-emit `plans/index.md` row.
7. `llm doctor`.

## Recipe: add a task

When the user (or the Lead) wants the next task: T<N+1>.

1. **Find the next N.** Count existing `t*.md` (excluding `handoff-*`); next number is N+1.
2. `llm flow plans/<PLAN-ID>/t<N>.md create`
3. Open `templates/task.md`; author the frontmatter:
   - `plan: <PLAN-ID>`, `task: T<N>`.
   - `depends-on: [T<prev>...]` — list task IDs in the same plan that must finish first. Empty if T1.
   - `concerns: [<area>/<concern>...]` — paths under `specs/` this task touches (subset of plan's `scope:`).
   - `files: [...]` — **predicted** files the task will create/modify. Lead's best estimate; not exhaustive.
   - `status: pending`.
   - `apps:` from the task's actual touch surface (may be a subset of the plan's `apps:`).
4. Body sections: `## What to do`, `## Context`, `## Implementation`, `## Done when` (concrete checkboxes).
5. Update the plan's `## Plan / DAG` table to include the new row.
6. Re-emit `plans/index.md` row (Tasks count went up: `0/4` → `0/5`).
7. `llm doctor`.

## Recipe: write a handoff (Dev role)

After completing a task — flip `t<N>.md` `status: in-progress` → `done`, then write `handoff-t<N>.md`:

1. `llm flow plans/<PLAN-ID>/handoff-t<N>.md create`
2. Open `templates/handoff.md`; author the frontmatter:
   - `plan: <PLAN-ID>`, `task: T<N>`.
   - `status: complete | partial | blocked`.
   - `date: <YYYY-MM-DD>`.
3. Body sections:
   - `## Files touched` — fill the `<!-- llm:files -->` block as a path-list (one bullet per file, `path — created | modified | removed (1 line)`).
   - `## Decisions made during implementation` — only what was NOT in the task (deviations, choices, discoveries).
   - `## Commands run / verification` — what you ran and the result.
   - `## Pending / follow-ups` — out of scope for this task. "None" is valid.
   - `## Suggestions for the Lead` — convention/gotcha not yet in `specs/`. "None" is valid.
4. Update `t<N>.md` frontmatter: `status: done`.
5. Update plan's `## Plan / DAG` Status column for T<N>: `pending` → `done`.
6. Re-emit `plans/index.md` row (Tasks: `1/5` → `2/5`).
7. `llm doctor` — file refs check should find the handoff's path-list resolves on disk.

## Recipe: draft the delta (plan close — Dev role)

When all tasks are `done` and the plan is ready to close:

1. **Pre-check.** Every `t<N>.md` has `status: done`; every `handoff-t<N>.md` exists.
2. `llm flow plans/<PLAN-ID>/delta-draft.md create`
3. Open `templates/delta-draft.md`; frontmatter:
   - `plan: <PLAN-ID>`, `status: draft`, `date: <YYYY-MM-DD>`.
4. Body — proposed changes to `specs/` per area touched. Use `### Added Requirements` / `### Modified Requirements` / `### Removed Requirements` per `specs/<area>/<concern>.md` file.
   - If no spec change is needed: single line `> No spec change required — <one-line rationale>.`
5. **Stop here.** Do not edit `specs/` directly. The Lead validates the draft and finalizes during `llm-archive`.
6. **Hand off to the Lead** — the next step is `llm-archive` (close + absorb).

## Recipe: transition a plan to "ready for archive"

When the user says "this plan is done" / "let's archive it":

1. Verify Dev finished step 4 (`delta-draft.md` exists with `status: draft`).
2. Verify every task `done` and every handoff present (same as the delta pre-check).
3. **Hand off to [`llm-archive`](../llm-archive/SKILL.md)** — it runs the archive recipe (move to `archive/<PLAN-ID>/`, finalize delta, absorb into specs, remove plan dir, re-emit indexes).

This skill does NOT perform the archive itself — that's `llm-archive`'s job. This skill just verifies the plan is in a state where archive can run.

## What this skill does NOT do

- **Archive** — `llm-archive` (move + absorb + remove).
- **Spec authoring** — `llm-specs` (bootstrap area, deepen, consolidate). The plan declares `scope:` paths; the spec skill creates/maintains the area files.
- **Intake / explore** — `llm-intake` (tracker mirror), `llm-explore` (pre-plan ideation).
- **Slash command exposure** — no `/llm:plan` slash command exists; invocation is via the user's natural-language request.

## Patterns

| User says | You do |
|---|---|
| "Start a plan for JET-1234" | Tracker-backed bootstrap recipe → confirm scope → create plan + maybe T1 → re-emit table |
| "Novo plano de manutenção pra limpar helpers deprecated" | Slug-based bootstrap recipe → propose slug → create plan with full body |
| "Add T3 to JET-1234" | Add-task recipe → next N → write task.md → update DAG → re-emit plans table |
| "Write the handoff for T2 of JET-1234" | Handoff recipe (Dev) → write handoff-t2.md → flip t2.md status → update DAG |
| "Draft the delta for JET-1234" | Delta-draft recipe (Dev) → verify all tasks done → create delta-draft.md |
| "Archive this plan" / "JET-1234 is ready" | Verify state → hand off to `llm-archive` |

Use `llm tag get/set` (CLI, no skill) for `plans/index.md` table round-trip; pair with `llm-archive` for plan close, `llm-specs` for the areas in `scope:`, and `llm-doctor` to verify between steps.
