---
human_revised: false
version: 1
name: cumaru-plan
description: Use this skill whenever the user wants to bootstrap, grow, or advance a plan in the project — open a new plan (tracker-backed or slug-based), add a task, write a handoff, draft the delta, or transition status. Trigger on phrases like "start a plan for AAA-1234", "novo plano de manutenção", "add task T3", "write the handoff for T2", "draft the delta", "transition the plan to done", "this plan is ready to archive", or any task that frames the work as authoring inside `plans/`. Skill is sdlc-only — it knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the role split (Lead authors plan + tasks; Dev writes handoffs + delta-draft).
summary: Use this skill whenever the user wants to bootstrap, grow, or advance a plan in the project — open a new plan (tracker-backed or slug-based), add a task, write a handoff, draft the delta, or transition status. Trigger on phrases like "start a plan for AAA-1234", "novo plano de manutenção", "add task T3", "write the handoff for T2", "draft the delta", "transition the plan to done", "this plan is ready to archive", or any task that frames the work as authoring inside `plans/`. Skill is sdlc-only — it knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the role split (Lead authors plan + tasks; Dev writes handoffs + delta-draft).
---

# `cumaru-plan` — author plans, tasks, handoffs, and the delta draft

The plan-lifecycle skill. Covers everything from bootstrap of a new `plans/<PLAN-ID>/` to readiness-for-archive. Archive itself lives in [`cumaru-archive`](../cumaru-archive/SKILL.md).

## Layout (recap from schema)

```
plans/<PLAN-ID>/
├── index.md          ← [scope!, status!, summary!, apps!, key, type, epic, story, aux]
├── t1.md             ← [plan!, task!, depends-on!, concerns!, files!, status!, apps!, aux!]
├── handoff-t1.md     ← [plan!, task!, status!, date!] + <!-- cumaru:touched --> ([Link, Description] table — one row per touched file)
├── t2.md             ...
└── delta-draft.md    ← [plan!, status!, date!]  (status: always `draft`)
```

`<PLAN-ID>`:
- Tracker-backed → `<KEY>` (e.g. `AAA-1234`). Requires `intake/<KEY>.md` to exist.
- Slug-based → `maintenance-<kebab-slug>` (e.g. `maintenance-cleanup-deprecated-helpers`). No `key:` in frontmatter.

**Role split**:
- **Lead** authors `index.md` + each `t<N>.md`.
- **Dev** writes `handoff-t<N>.md` (after completing T<N>) and `delta-draft.md` (at plan close).

## Recipe: bootstrap a new plan (tracker-backed)

When the user says "start a plan for AAA-1234" / "vamos começar AAA-1234":

1. **Pre-check.** `intake/<KEY>.md` must exist. If not, run `cumaru intake <KEY>` first.
2. **Read the intake.** Overview + Acceptance Criteria live there — don't duplicate into the plan.
3. **Decide scope by traversing `specs/` under the loading rule.** Read `specs/index.md`, run `cumaru tree specs`, combine selected candidates with domain-declared semantic links, prune by relevance, and recurse only into selected directories. The proposed `scope:` is exactly the leaf paths the traversal surfaces — never a skim. **Confirm with the user.**
4. `cumaru flow plans/<KEY> create`
5. `cumaru flow plans/<KEY>/index.md create`
6. Open `templates/plan.md`; author the frontmatter:
   - `key: <KEY>`, `type:` (task | story | bug | spike from intake), optional `epic:`, `story:`.
   - `scope: [<list from step 3>]`.
   - `status: in-progress` (drafting is fine if you're still arguing scope; flip to in-progress when work starts).
   - `summary:` one-line (will appear in `plans/index.md`).
   - `apps: [...]` from intake's `apps:`.
7. Body — tracker-backed plans carry **only** `## Plan / DAG`, `## Out of scope`, `## Risks`. Overview + AC are in intake.
8. Skip task creation now if you don't yet know the breakdown; add them as the work clarifies (see "Recipe: add a task" below). Or seed `t1.md` with the first task immediately.
9. **Reconcile the written plan against the intake (coverage gate).** Before continuing, prove the plan faithfully executes what the intake requests — checked, not assumed:
   - **Intake is sound first.** Re-open `intake/<KEY>.md`: no `<!-- BEGIN RAW` block lingers (a still-raw issue invalidates every check below), `## Overview` is written, and `## Acceptance Criteria (EARS / RFC 2119)` lists concrete criteria.
   - **Every criterion has a home.** Map each acceptance criterion → the `scope:` path that satisfies it → (once tasks exist) the task that does the work. A criterion with no scope/task is a gap.
   - **No dead scope.** Every `scope:` path resolves to a real `specs/<area>/` (or is explicitly flagged bootstrap-on-first-touch) **and** is actually exercised — referenced by some task's `concerns:`. A scope path no task touches is decoration; drop it or add the task. No task's `concerns:` points outside `scope:`.
   - **Scope is complete, not just covered.** Read the change's reach from the `depends-on` / `relates` graph: does `scope:` name every capability/flow the change can cross, or only the one that motivated the plan? A surface whose reach the graph doesn't describe is bootstrapped (node + edges) before tasks (see the `blast-radius` discipline).
   - **The body agrees.** Re-read `index.md` against the above: `## Plan / DAG` covers every criterion, `## Out of scope` drops nothing silently, `## Risks` are the real ones.
   - **Update and re-check.** If any check fails, fix the plan — `scope:`, tasks, or body — then re-run this step. Proceed only when intake and plan agree.
10. Run `cumaru tree plans` to verify the new directory is discoverable by its `summary:`.
11. `cumaru doctor` — navigation and summary checks clean.

## Recipe: bootstrap a new plan (slug-based / maintenance)

When the user says "novo plano de manutenção <X>" / "internal refactor of Y, no ticket":

1. **Decide the slug.** Kebab-case, prefixed with `maintenance-`. Confirm.
2. `cumaru flow plans/maintenance-<slug> create`
3. `cumaru flow plans/maintenance-<slug>/index.md create`
4. Frontmatter — no `key:`, no `type:`, no `epic:`/`story:`. Required: `scope`, `status: in-progress`, `summary`, `apps`.
5. Body — slug-based plans carry **everything** (no intake to defer to): `## Overview` + `## Acceptance Criteria (EARS / RFC 2119)` + `## Plan / DAG` + `## Out of scope` + `## Risks`.
6. Run `cumaru tree plans` to verify navigation.
7. `cumaru doctor`.

## Recipe: add a task

When the user (or the Lead) wants the next task: T<N+1>.

1. **Find the next N.** Count existing `t*.md` (excluding `handoff-*`); next number is N+1.
2. `cumaru flow plans/<PLAN-ID>/t<N>.md create`
3. Open `templates/task.md`; author the frontmatter:
   - `plan: <PLAN-ID>`, `task: T<N>`.
   - `depends-on: [T<prev>...]` — list task IDs in the same plan that must finish first. Empty if T1.
   - `concerns: [<area>/<concern>...]` — paths under `specs/` this task touches (subset of plan's `scope:`).
   - `files: [...]` — **predicted** files the task will create/modify. Lead's best estimate; not exhaustive.
   - `status: pending`.
   - `apps:` from the task's actual touch surface (may be a subset of the plan's `apps:`).
4. Body sections: `## What to do`, `## Context`, `## Implementation`, `## Done when` (concrete checkboxes).
5. Update the plan's `## Plan / DAG` table to include the new row.
6. Run `cumaru tree plans` to verify navigation.
7. `cumaru doctor`.

## Recipe: write a handoff (Dev role)

After completing a task — flip `t<N>.md` `status: in-progress` → `done`, then write `handoff-t<N>.md`:

1. `cumaru flow plans/<PLAN-ID>/handoff-t<N>.md create`
2. Open `templates/handoff.md`; author the frontmatter:
   - `plan: <PLAN-ID>`, `task: T<N>`.
   - `status: complete | partial | blocked`.
   - `date: <YYYY-MM-DD>`.
3. Body sections:
   - `## Files touched` — fill the `<!-- cumaru:touched -->` block as a `[Link, Description]` table, one row per file: `| [`<path>`](<path>) | created/modified/removed — one-line description of the change |`. Use `git diff --name-status` to enumerate; the LLM writes the description per file.
   - `## Decisions made during implementation` — only what was NOT in the task (deviations, choices, discoveries).
   - `## Commands run / verification` — what you ran and the result.
   - `## Pending / follow-ups` — out of scope for this task. "None" is valid.
   - `## Suggestions for the Lead` — convention/gotcha not yet in `specs/`. "None" is valid.
4. Update `t<N>.md` frontmatter: `status: done`.
5. Update plan's `## Plan / DAG` Status column for T<N>: `pending` → `done`.
6. Run `cumaru tree plans` to verify navigation.
7. `cumaru doctor` — file refs check should find every link in the handoff's `<!-- cumaru:touched -->` table resolves on disk.

## Recipe: draft the delta (plan close — Dev role)

When all tasks are `done` and the plan is ready to close:

1. **Pre-check.** Every `t<N>.md` has `status: done`; every `handoff-t<N>.md` exists.
2. `cumaru flow plans/<PLAN-ID>/delta-draft.md create`
3. Open `templates/delta-draft.md`; frontmatter:
   - `plan: <PLAN-ID>`, `status: draft`, `date: <YYYY-MM-DD>`.
4. Body — proposed changes to `specs/` per area touched. Use `### Added Requirements` / `### Modified Requirements` / `### Removed Requirements` per `specs/<area>/<concern>.md` file.
   - If no spec change is needed: single line `> No spec change required — <one-line rationale>.`
5. **Stop here.** Do not edit `specs/` directly. The Lead validates the draft and finalizes during `cumaru-archive`.
6. **Hand off to the Lead** — the next step is `cumaru-archive` (close + absorb).

## Recipe: transition a plan to "ready for archive"

When the user says "this plan is done" / "let's archive it":

1. Verify Dev finished step 4 (`delta-draft.md` exists with `status: draft`).
2. Verify every task `done` and every handoff present (same as the delta pre-check).
3. **Hand off to [`cumaru-archive`](../cumaru-archive/SKILL.md)** — it runs the archive recipe (move to `archive/<PLAN-ID>/`, finalize delta, absorb into specs, and remove plan files).

This skill does NOT perform the archive itself — that's `cumaru-archive`'s job. This skill just verifies the plan is in a state where archive can run.

## What this skill does NOT do

- **Archive** — `cumaru-archive` (move + absorb + remove).
- **Spec authoring** — `cumaru-specs` (bootstrap area, deepen, consolidate). The plan declares `scope:` paths; the spec skill creates/maintains the area files.
- **Intake / explore** — `cumaru-intake` (tracker mirror), `cumaru-explore` (pre-plan ideation).
- **Slash command exposure** — no `/cumaru:plan` slash command exists; invocation is via the user's natural-language request.

## Patterns

| User says | You do |
|---|---|
| "Start a plan for AAA-1234" | Tracker-backed bootstrap recipe → confirm scope → create plan + maybe T1 → verify with `cumaru tree plans --rows` |
| "Novo plano de manutenção pra limpar helpers deprecated" | Slug-based bootstrap recipe → propose slug → create plan with full body |
| "Add T3 to AAA-1234" | Add-task recipe → next N → write task.md → update DAG → verify with `cumaru tree plans --rows` |
| "Write the handoff for T2 of AAA-1234" | Handoff recipe (Dev) → write handoff-t2.md → flip t2.md status → update DAG |
| "Draft the delta for AAA-1234" | Delta-draft recipe (Dev) → verify all tasks done → create delta-draft.md |
| "Archive this plan" / "AAA-1234 is ready" | Verify state → hand off to `cumaru-archive` |

Use `cumaru tag get/set` (CLI, no skill) for `plans/index.md` table round-trip; pair with `cumaru-archive` for plan close, `cumaru-specs` for the areas in `scope:`, and `cumaru-doctor` to verify between steps.
