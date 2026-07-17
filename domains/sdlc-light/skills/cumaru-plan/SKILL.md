---
human_revised: false
version: 1
name: cumaru-plan
description: Use this skill whenever the user wants to bootstrap, grow, or advance a plan in the project — open a new plan (tracker-backed or slug-based), add a task, write a handoff, draft the delta, or transition status. Trigger on phrases like "start a plan for AAA-1234", "novo plano de manutenção", "add task T3", "write the handoff for T2", "draft the delta", "transition the plan to done", or any task that frames the work as authoring inside `plans/`. Skill is sdlc-light-only — it knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the Admin role (unrestricted, single role).
summary: Use this skill whenever the user wants to bootstrap, grow, or advance a plan in the project — open a new plan (tracker-backed or slug-based), add a task, write a handoff, draft the delta, or transition status. Trigger on phrases like "start a plan for AAA-1234", "novo plano de manutenção", "add task T3", "write the handoff for T2", "draft the delta", "transition the plan to done", or any task that frames the work as authoring inside `plans/`. Skill is sdlc-light-only — it knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the Admin role (unrestricted, single role).
---

# `cumaru-plan` — author plans, tasks, handoffs, and the delta draft

The plan-lifecycle skill for sdlc-light. Covers everything from bootstrap of a new `plans/<PLAN-ID>/` to readiness-for-absorb. Absorb itself lives in [`cumaru-absorb`](../cumaru-absorb/SKILL.md).

## Layout (recap from schema)

```
plans/<PLAN-ID>/
├── index.md          ← [scope!, status!, summary!, apps!, key, type, epic, story, aux]
├── t1.md             ← [plan!, task!, depends-on!, concerns!, files!, status!, apps!, aux!]
├── handoff-t1.md     ← [plan!, task!, status!, date!] + <!-- cumaru:touched --> ([Link, Description] table)
├── t2.md             ...
└── delta-draft.md    ← [plan!, status!, date!]  (status: always `draft`)
```

`<PLAN-ID>`:
- Tracker-backed → `<KEY>` (e.g. `AAA-1234`).
- Slug-based → `maintenance-<kebab-slug>` (e.g. `maintenance-cleanup-deprecated-helpers`). No `key:` in frontmatter.

**Role**: Admin — unrestricted. Authors everything, writes handoffs, drafts deltas.

## Recipe: bootstrap a new plan (tracker-backed)

When the user says "start a plan for AAA-1234" / "vamos começar AAA-1234":

1. **Decide scope by traversing `specs/` under the loading rule.** Read `specs/index.md`, run `cumaru tree specs --deep --rows`, prune candidates by relevance, and terminate at the relevant `<concern>.md` leaves. The proposed `scope:` is exactly the set of leaf paths surfaced by that traversal. **Confirm with the user.**
2. `cumaru flow plans/<KEY> create`
3. `cumaru flow plans/<KEY>/index.md create`
4. Open `templates/plan.md`; author the frontmatter:
   - `key: <KEY>`, `type:` (task | story | bug | spike), optional `epic:`, `story:`.
   - `scope: [<list from step 1>]`.
   - `status: in-progress`.
   - `summary:` one-line.
   - `apps: [...]`.
5. Body — carries **everything** (no separate intake pillar): `## Overview`, `## Acceptance Criteria (EARS / RFC 2119)`, `## Plan / DAG`, `## Out of scope`, `## Risks`.
6. Skip task creation now if you don't yet know the breakdown; add them as the work clarifies.
7. run `cumaru tree plans --rows` .
8. `cumaru doctor` — navigation and summary checks clean.

## Recipe: bootstrap a new plan (slug-based / maintenance)

1. **Decide the slug.** Kebab-case, prefixed with `maintenance-`. Confirm.
2. `cumaru flow plans/maintenance-<slug> create`
3. `cumaru flow plans/maintenance-<slug>/index.md create`
4. Frontmatter — no `key:`, no `type:`, no `epic:`/`story:`. Required: `scope`, `status: in-progress`, `summary`, `apps`.
5. Body — same sections as tracker-backed: `## Overview`, `## Acceptance Criteria (EARS / RFC 2119)`, `## Plan / DAG`, `## Out of scope`, `## Risks`.
6. run `cumaru tree plans --rows`.
7. `cumaru doctor`.

## Recipe: add a task

1. **Find the next N.** Count existing `t*.md` (excluding `handoff-*`); next number is N+1.
2. `cumaru flow plans/<PLAN-ID>/t<N>.md create`
3. Open `templates/task.md`; author the frontmatter.
4. Body sections: `## What to do`, `## Context`, `## Implementation`, `## Done when`.
5. Update the plan's `## Plan / DAG` table to include the new row.
6. run `cumaru tree plans --rows`.
7. `cumaru doctor`.

## Recipe: write a handoff

After completing a task — flip `t<N>.md` `status: in-progress` → `done`, then write `handoff-t<N>.md`:

1. `cumaru flow plans/<PLAN-ID>/handoff-t<N>.md create`
2. Open `templates/handoff.md`; author the frontmatter and body.
3. Update `t<N>.md` frontmatter: `status: done`.
4. Update plan's `## Plan / DAG` Status column for T<N>.
5. run `cumaru tree plans --rows`.
6. `cumaru doctor`.

## Recipe: draft the delta (plan close)

When all tasks are `done` and the plan is ready to close:

1. **Pre-check.** Every `t<N>.md` has `status: done`; every `handoff-t<N>.md` exists.
2. `cumaru flow plans/<PLAN-ID>/delta-draft.md create`
3. Open `templates/delta-draft.md`; frontmatter: `plan: <PLAN-ID>`, `status: draft`, `date: <YYYY-MM-DD>`.
4. Body — proposed changes to `specs/` per area touched. Use `### Added Requirements` / `### Modified Requirements` / `### Removed Requirements` per spec file.
   - If no spec change is needed: single line `> No spec change required — <one-line rationale>.`
5. **Stop here.** Do not edit `specs/` directly yet. The next step is `cumaru-absorb` (validate + absorb).

## Recipe: transition a plan to "ready for absorb"

1. Verify delta-draft exists with `status: draft`.
2. Verify every task `done` and every handoff present.
3. **Hand off to [`cumaru-absorb`](../cumaru-absorb/SKILL.md)** — it validates the delta, updates specs, cleans up plan files, and verifies the resulting tree projection.

## What this skill does NOT do

- **Absorb** — `cumaru-absorb` (validate delta, update specs, clean up).
- **Spec authoring** — `cumaru-specs` (bootstrap area, deepen, consolidate).
- **Explore / promote** — `cumaru-explore` (pre-plan ideation, promote to plans).

## Patterns

| User says | You do |
|---|---|
| "Start a plan for AAA-1234" | Bootstrap recipe → confirm scope → create plan + maybe T1 → verify with `cumaru tree plans --rows` |
| "Novo plano de manutenção pra limpar helpers deprecated" | Slug-based bootstrap recipe → propose slug → create plan with full body |
| "Add T3 to AAA-1234" | Add-task recipe → next N → write task.md → update DAG → verify with `cumaru tree plans --rows` |
| "Write the handoff for T2 of AAA-1234" | Handoff recipe → write handoff-t2.md → flip t2.md status → update DAG |
| "Draft the delta for AAA-1234" | Delta-draft recipe → verify all tasks done → create delta-draft.md |
| "Absorb this plan" / "AAA-1234 is ready" | Verify state → hand off to `cumaru-absorb` |

Use `cumaru tag get/set` (CLI, no skill) for `plans/index.md` table round-trip; pair with `cumaru-absorb` for plan close, `cumaru-specs` for the areas in `scope:`, and `cumaru-doctor` to verify between steps.
