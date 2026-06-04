---
human_revised: false
version: 1
name: llm-plan
description: Use this skill whenever the user wants to bootstrap, grow, or advance a changeset — open a new change (tracker-backed or slug-based), add an apply step, write a handoff, draft the delta, or transition status. Trigger on phrases like "start a change for JET-1234", "novo plano de manutenção", "add step T3", "write the handoff for T2", "draft the delta", "this change is ready to archive", or any task framed as authoring inside `plans/`. Knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the role split (Lead authors the changeset + steps; Dev writes handoffs + delta-draft).
---

# `llm-plan` — author changesets, apply steps, handoffs, and the delta draft

The changeset-lifecycle skill. From bootstrap of a new `plans/<PLAN-ID>/` to readiness-for-archive. Archive itself lives in [`llm-archive`](../llm-archive/SKILL.md).

## Layout (recap from schema)

```
plans/<PLAN-ID>/
├── index.md          ← [scope!, status!, summary!, apps!, key, type, epic, story, aux]
├── t1.md             ← [plan!, task!, depends-on!, concerns!, files!, status!, apps!, aux!]
├── handoff-t1.md     ← [plan!, task!, status!, date!] + <!-- llm:files --> (path-list)
└── delta-draft.md    ← [plan!, status!, date!]  (status: always `draft`)
```

`<PLAN-ID>`: tracker-backed → `<KEY>` (requires `intake/<KEY>/`); slug-based → `maintenance-<kebab-slug>` (no `key:`).

**Role split:** Lead authors `index.md` + each `t<N>.md`; Dev writes `handoff-t<N>.md` (per applied step) and `delta-draft.md` (at change close).

## Recipe: bootstrap a changeset (tracker-backed)

1. **Pre-check.** `intake/<KEY>/index.md` must exist (else `llm intake <KEY>`).
2. **Read the intake** — Overview + Acceptance Criteria live there; don't duplicate.
3. **Decide scope.** Propose the `topology/<area>[/<subarea>]` paths this change touches (read intake + skim `topology/`). **Confirm.**
4. `llm flow plans/<KEY> create` → `llm flow plans/<KEY>/index.md create`
5. Open `templates/plan.md`; author frontmatter (`key`, `type`, `scope`, `status: in-progress`, `summary`, `apps` = target environments).
6. Body — tracker-backed changes carry `## Plan / DAG`, **`## Blast radius`**, **`## Rollback`**, **`## Promotion path`**, `## Out of scope`, `## Risks`. Overview + AC stay in intake.
   - **Blast radius / Rollback are not optional.** State what can break, across which environments, and what is irreversible — before any apply.
   - **Promotion path** records the environment order (dev → staging → prod) and the gate between each.
7. Seed `t1.md` now or add steps as the breakdown clarifies (see below).
8. Re-emit `plans/index.md` row via `llm tag set plans/index.md plans <new body>` (Key | Title | Tasks | Apps; `Tasks` = `done/total`).
9. `llm doctor`.

## Recipe: bootstrap a changeset (slug-based / maintenance)

Kebab-case slug prefixed `maintenance-`. Frontmatter has no `key:`/`type:`. Body carries **everything** (no intake to defer to): `## Overview` + `## Acceptance Criteria (EARS)` + `## Plan / DAG` + `## Blast radius` + `## Rollback` + `## Promotion path` + `## Out of scope` + `## Risks`. Re-emit `plans/index.md`; `llm doctor`.

## Recipe: add an apply step

1. Next N = count `t*.md` (excluding `handoff-*`) + 1.
2. `llm flow plans/<PLAN-ID>/t<N>.md create`
3. Open `templates/task.md`; frontmatter: `plan`, `task: T<N>`, `depends-on:` (apply order within the change), `concerns:` (`topology/` paths it touches), `files:` (predicted HCL/manifests), `status: pending`, `apps:` (the environments this step applies to).
4. Body: `## What to do`, `## Context`, `## Apply` (the exact `plan`/`apply` commands + expected diff + manual gate), `## Verify`, `## Done when`.
5. Update the plan's `## Plan / DAG` table; re-emit `plans/index.md`; `llm doctor`.

## Recipe: write a handoff (Dev role)

After applying a step — flip `t<N>.md` `status: done`, then write `handoff-t<N>.md` from `templates/handoff.md`:

- Frontmatter: `plan`, `task`, `status: complete | partial | blocked`, `date`.
- `## Files touched` — fill the `<!-- llm:files -->` path-list (HCL/manifests/modules changed).
- `## Decisions made during implementation` — deviations, choices, discoveries (incl. **the actual `plan` diff** if it differed from expectation).
- `## Commands run / verification` — the `apply` result + verification.
- `## Pending / follow-ups`, `## Suggestions for the Lead` — "None" is valid.
- Update the DAG Status; re-emit `plans/index.md`; `llm doctor`.

**Stop and surface** (do not apply) if the `plan` diff shows an unintended destroy/replace or drifts from the step.

## Recipe: draft the delta (change close — Dev role)

When all steps are `done`:

1. Pre-check: every `t<N>.md` done; every `handoff-t<N>.md` exists.
2. `llm flow plans/<PLAN-ID>/delta-draft.md create` from `templates/delta-draft.md` (`status: draft`).
3. Body — proposed changes to `topology/` per area touched (`### Added / Modified / Removed`), or `> No topology change required — <rationale>.`
4. **Stop.** Do not edit `topology/` directly — the Lead validates + finalizes during `llm-archive`.

## Recipe: ready for archive

Verify `delta-draft.md` exists (`status: draft`), every step done + handoff present, then **hand off to [`llm-archive`](../llm-archive/SKILL.md)**. This skill does not perform the archive.

## What this skill does NOT do

- **Archive** — `llm-archive`. **Topology authoring** — `llm-topology` (creates the `scope:` areas). **Intake / explore** — `llm-intake`, `llm-explore`. **Drawing** — `llm-arch`.

## Patterns

| User says | You do |
|---|---|
| "Start a change for JET-1234" | Tracker-backed bootstrap → confirm scope → create plan + maybe T1 → re-emit table |
| "Novo plano de manutenção pra rotacionar os certs" | Slug-based bootstrap → propose slug → full body (incl. blast radius/rollback) |
| "Add step T3 to JET-1234" | Add-step recipe → write t3.md (Apply/Verify) → update DAG → re-emit |
| "Write the handoff for T2" | Handoff recipe (Dev) → record the apply diff → flip status |
| "Draft the delta for JET-1234" | Delta-draft recipe (Dev) → verify steps done → propose topology changes |
| "Archive this change" | Verify state → hand off to `llm-archive` |

Use `llm tag get/set` (CLI) for `plans/index.md`; pair with `llm-archive`, `llm-topology`, `llm-doctor`.
