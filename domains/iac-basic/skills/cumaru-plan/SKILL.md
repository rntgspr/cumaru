---
human_revised: false
version: 1
name: cumaru-plan
description: Use this skill whenever the user wants to bootstrap, grow, or advance a changeset — open a new change (tracker-backed or slug-based), add an apply step, write a handoff, draft the delta, or transition status. Trigger on phrases like "start a change for AAA-1234", "novo plano de manutenção", "add step T3", "write the handoff for T2", "draft the delta", "this change is ready to absorption", or any task framed as authoring inside `plans/`. Knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the role split (Lead authors the changeset + steps; Dev writes handoffs + delta-draft).
summary: Use this skill whenever the user wants to bootstrap, grow, or advance a changeset — open a new change (tracker-backed or slug-based), add an apply step, write a handoff, draft the delta, or transition status. Trigger on phrases like "start a change for AAA-1234", "novo plano de manutenção", "add step T3", "write the handoff for T2", "draft the delta", "this change is ready to absorption", or any task framed as authoring inside `plans/`. Knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the role split (Lead authors the changeset + steps; Dev writes handoffs + delta-draft).
---

# `cumaru-plan` — author changesets, apply steps, handoffs, and the delta draft

The changeset-lifecycle skill. From bootstrap of a new `plans/<PLAN-ID>/` to readiness-for-absorption. Absorption itself lives in [`cumaru-absorb`](../cumaru-absorb/SKILL.md).

## Invocation

Use invocation arguments as a changeset ID or requested action. Run `cumaru
doctor --quiet` first; if errors affect `plans/`, `intake/`, or `topology/`,
surface them and ask whether to repair them before proceeding. If a tracker key
has no intake entry, offer `cumaru-intake`, then resume after it exists. A
changeset is ready for absorption only after its delta draft exists and it has
landed in every environment in its promotion path.

## Layout (recap from schema)

```
plans/<PLAN-ID>/
├── index.md          ← [scope!, status!, summary!, targets!, key, type, epic, story, aux]
├── t1.md             ← [plan!, task!, depends-on!, concerns!, files!, status!, targets!, aux!]
├── handoff-t1.md     ← [plan!, task!, status!, date!] + <!-- cumaru:touched --> ([Link, Description] table — one row per touched HCL/manifest/module)
└── delta-draft.md    ← [plan!, status!, date!]  (status: always `draft`)
```

`<PLAN-ID>`: tracker-backed → `<KEY>` (requires `intake/<KEY>/`); slug-based → `maintenance-<kebab-slug>` (no `key:`).

**Role split:** Lead authors `index.md` + each `t<N>.md`; Dev writes `handoff-t<N>.md` (per applied step) and `delta-draft.md` (at change close).

## Recipe: bootstrap a changeset (tracker-backed)

1. **Pre-check.** `intake/<KEY>/index.md` must exist; otherwise hand off to `cumaru-intake`.
2. **Read the intake** — Overview + Acceptance Criteria live there; don't duplicate.
3. **Decide scope by traversing `topology/` under the loading rule.** Read `topology/index.md`, run `cumaru tree topology --rows`, prune candidates by relevance, then follow semantic `depends-on` and `relates` links from the surviving entities. The proposed `scope:` is exactly the set of relevant leaf paths surfaced by that traversal. **Confirm.**
4. `cumaru fs plans/<KEY> create` → `cumaru fs plans/<KEY>/index.md create`
5. Open `templates/plan.md`; author frontmatter (`key`, `type`, `scope`, `status: in-progress`, `summary`, `targets` = target environments).
6. Body — tracker-backed changes carry `## Plan / DAG`, **`## Blast radius`**, **`## Rollback`**, **`## Promotion path`**, `## Out of scope`, `## Risks`. Overview + AC stay in intake.
   - **Blast radius / Rollback are not optional.** State what can break, across which environments, and what is irreversible — before any apply.
   - **Promotion path** records the environment order (dev → staging → prod) and the gate between each.
7. Seed `t1.md` now or add steps as the breakdown clarifies (see below).
8. Run `cumaru tree plans --rows` and verify the plan summary.
9. `cumaru doctor`.

## Recipe: bootstrap a changeset (slug-based / maintenance)

Kebab-case slug prefixed `maintenance-`. Frontmatter has no `key:`/`type:`. Body carries **everything** (no intake to defer to): `## Overview` + `## Acceptance Criteria (EARS / RFC 2119)` + `## Plan / DAG` + `## Blast radius` + `## Rollback` + `## Promotion path` + `## Out of scope` + `## Risks`. run `cumaru tree plans --rows`; `cumaru doctor`.

## Recipe: add an apply step

1. Next N = count `t*.md` (excluding `handoff-*`) + 1.
2. `cumaru fs plans/<PLAN-ID>/t<N>.md create`
3. Open `templates/task.md`; frontmatter: `plan`, `task: T<N>`, `depends-on:` (apply order within the change), `concerns:` (`topology/` paths it touches), `files:` (predicted HCL/manifests), `status: pending`, `targets:` (the environments this step applies to).
4. Body: `## What to do`, `## Context`, `## Apply` (the exact `plan`/`apply` commands + expected diff + manual gate), `## Verify`, `## Done when`.
5. Update the plan's `## Plan / DAG` table; run `cumaru tree plans --rows`; `cumaru doctor`.

## Recipe: write a handoff (Dev role)

After applying a step — flip `t<N>.md` `status: done`, then write `handoff-t<N>.md` from `templates/handoff.md`:

- Frontmatter: `plan`, `task`, `status: complete | partial | blocked`, `date`.
- `## Files touched` — fill the `<!-- cumaru:touched -->` block as a `[Link, Description]` table, one row per file: `| [`<path>`](<path>) | created/modified/removed — one-line description of the change |`.
- `## Decisions made during implementation` — deviations, choices, discoveries (incl. **the actual `plan` diff** if it differed from expectation).
- `## Commands run / verification` — the `apply` result + verification.
- `## Pending / follow-ups`, `## Suggestions for the Lead` — "None" is valid.
- Return the step status and handoff evidence to Lead. Dev does not edit the
  plan index, DAG row, or changeset status; Lead reconciles them. Run `cumaru doctor`.

**Stop and surface** (do not apply) if the `plan` diff shows an unintended destroy/replace or drifts from the step.

## Recipe: draft the delta (change close — Dev role)

When all steps are `done`:

1. Pre-check: every `t<N>.md` done; every `handoff-t<N>.md` exists.
2. `cumaru fs plans/<PLAN-ID>/delta-draft.md create` from `templates/delta-draft.md` (`status: draft`).
3. Body — proposed changes to topology structure, interfaces, apply-order
   dependencies, decisions, or cost/security posture per area touched, using
   the headings from `templates/delta-draft.md`; never add Requirements
   sections. If nothing durable changed, use
   `> No topology change required — <rationale>.`
4. **Stop.** Do not edit `topology/` directly — the Lead validates + finalizes during `cumaru-absorb`.

## Recipe: ready for absorption

Verify `delta-draft.md` exists (`status: draft`), every step done + handoff present, then **hand off to [`cumaru-absorb`](../cumaru-absorb/SKILL.md)**. This skill does not perform the absorption.

## What this skill does NOT do

- **Absorption** — `cumaru-absorb`. **Topology authoring** — `cumaru-topology` (creates the `scope:` areas). **Intake / explore** — `cumaru-intake`, `cumaru-explore`. **Drawing** — `cumaru-arch`.

## Patterns

| User says | You do |
|---|---|
| "Start a change for AAA-1234" | Tracker-backed bootstrap → confirm scope → create plan + maybe T1 → verify with `cumaru tree plans --rows` |
| "Novo plano de manutenção pra rotacionar os certs" | Slug-based bootstrap → propose slug → full body (incl. blast radius/rollback) |
| "Add step T3 to AAA-1234" | Add-step recipe → write t3.md (Apply/Verify) → update DAG → run `cumaru tree` |
| "Write the handoff for T2" | Handoff recipe (Dev) → record the apply diff → flip status |
| "Draft the delta for AAA-1234" | Delta-draft recipe (Dev) → verify steps done → propose topology changes |
| "Absorption this change" | Verify state → hand off to `cumaru-absorb` |

Use `cumaru tag get/set` (CLI) for `plans/index.md`; pair with `cumaru-absorb`, `cumaru-topology`, `cumaru-doctor`.
