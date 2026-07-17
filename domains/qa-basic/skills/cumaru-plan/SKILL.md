---
human_revised: false
version: 1
name: cumaru-plan
description: Use this skill whenever the user wants to bootstrap, grow, or advance a test campaign — open a new campaign (tracker-backed or slug-based), add a case, write a handoff, draft the coverage delta, or transition status. Trigger on phrases like "start a campaign for AAA-1234", "nova campanha de testes", "add case T3", "write the handoff for T2", "draft the delta", "this campaign is ready to archive", or any task framed as authoring inside `plans/`. Knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the role split (Lead authors the campaign + cases; Dev writes handoffs + delta-draft).
summary: Use this skill whenever the user wants to bootstrap, grow, or advance a test campaign — open a new campaign (tracker-backed or slug-based), add a case, write a handoff, draft the coverage delta, or transition status. Trigger on phrases like "start a campaign for AAA-1234", "nova campanha de testes", "add case T3", "write the handoff for T2", "draft the delta", "this campaign is ready to archive", or any task framed as authoring inside `plans/`. Knows the pillar layout (`plans/<KEY>/`, `t<N>.md`, `handoff-t<N>.md`, `delta-draft.md`) and the role split (Lead authors the campaign + cases; Dev writes handoffs + delta-draft).
---

# `cumaru-plan` — author test campaigns, cases, handoffs, and the delta draft

The campaign-lifecycle skill. From bootstrap of a new `plans/<PLAN-ID>/` to readiness-for-archive. Archive itself lives in [`cumaru-archive`](../cumaru-archive/SKILL.md).

## Layout (recap from schema)

```
plans/<PLAN-ID>/
├── index.md          ← [scope!, status!, summary!, apps!, key, type, epic, story, aux]
├── t1.md             ← [plan!, task!, depends-on!, concerns!, files!, status!, apps!, aux!]
├── handoff-t1.md     ← [plan!, task!, status!, date!] + <!-- cumaru:touched --> ([Link, Description] table — one row per touched spec/fixture/factory)
└── delta-draft.md    ← [plan!, status!, date!]  (status: always `draft`)
```

`<PLAN-ID>`: tracker-backed → `<KEY>` (requires `intake/<KEY>/`); slug-based → `maintenance-<kebab-slug>` (no `key:`).

**Role split:** Lead authors `index.md` + each `t<N>.md`; Dev writes `handoff-t<N>.md` (per authored case) and `delta-draft.md` (at campaign close).

## Recipe: bootstrap a campaign (tracker-backed)

1. **Pre-check.** `intake/<KEY>/index.md` must exist (else `cumaru intake <KEY>`).
2. **Read the intake** — Overview + Acceptance Criteria (the requirement to verify) live there; don't duplicate.
3. **Decide scope by traversing `coverage/` under the loading rule.** Read `coverage/index.md`, run `cumaru tree coverage --rows`, prune candidates by relevance, then follow semantic `depends-on` and `relates` links from the surviving entities. The proposed `scope:` is exactly the set of relevant leaf paths surfaced by that traversal. **Confirm.**
4. `cumaru flow plans/<KEY> create` → `cumaru flow plans/<KEY>/index.md create`
5. Open `templates/plan.md`; author frontmatter (`key`, `type`, `scope`, `status: in-progress`, `summary`, `apps` = target levels).
6. Body — tracker-backed campaigns carry `## Test Strategy`, `## Cases / DAG`, `## Scope`, `## Risks / Gaps`, `## Out of scope`. Overview + AC stay in intake.
   - **Test Strategy** states which levels cover what and **why** — keep the pyramid; justify any e2e a lower level could catch. Reference the relevant `standards/` instead of restating them.
   - **Scope** names the `coverage/` paths and the `intake/<KEY>` each covers — the traceability link.
7. Seed `t1.md` now or add cases as the breakdown clarifies (see below).
8. Run `cumaru tree plans --rows` and verify the plan summary.
9. `cumaru doctor`.

## Recipe: bootstrap a campaign (slug-based / maintenance)

Kebab-case slug prefixed `maintenance-` (e.g. `maintenance-deflake-checkout`). Frontmatter has no `key:`/`type:`. Body carries **everything** (no intake to defer to): `## Overview` + `## Acceptance Criteria (EARS / RFC 2119)` + `## Test Strategy` + `## Cases / DAG` + `## Scope` + `## Risks / Gaps` + `## Out of scope`. run `cumaru tree plans --rows`; `cumaru doctor`.

## Recipe: add a case

1. Next N = count `t*.md` (excluding `handoff-*`) + 1.
2. `cumaru flow plans/<PLAN-ID>/t<N>.md create`
3. Open `templates/task.md`; frontmatter: `plan`, `task: T<N>`, `depends-on:` (authoring order within the campaign), `concerns:` (`coverage/` paths it touches), `files:` (predicted spec/fixture files), `status: pending`, `apps:` (the levels this case is written at).
4. Body: `## What to do`, `## Context`, `## Author / Automate` (which fixtures/mocks per `standards/`, the runner command), `## Verify` (meaningful + non-flaky), `## Done when`.
5. Update the plan's `## Cases / DAG` table; run `cumaru tree plans --rows`; `cumaru doctor`.

## Recipe: write a handoff (Dev role)

After authoring/automating a case — flip `t<N>.md` `status: done`, then write `handoff-t<N>.md` from `templates/handoff.md`:

- Frontmatter: `plan`, `task`, `status: complete | partial | blocked`, `date`.
- `## Files touched` — fill the `<!-- cumaru:touched -->` block as a `[Link, Description]` table, one row per file: `| [`<path>`](<path>) | created/modified/removed — one-line description of the change |`.
- `## Scenarios covered` — each `GIVEN … WHEN … THEN …` at its level, mapping to an `intake/<KEY>` AC.
- `## Decisions made during authoring` — deviations, choices (what to mock, which fixture), discoveries.
- `## Commands run / verification` — the runner result + the flakiness check (N repeated runs).
- `## Pending / follow-ups`, `## Suggestions for the Lead` — "None" is valid.
- Update the DAG Status; run `cumaru tree plans --rows`; `cumaru doctor`.

**Stop and surface** (don't silently promote a level) if a `unit` case turns out to need a real collaborator — flag it in the handoff.

## Recipe: draft the delta (campaign close — Dev role)

When all cases are `done`:

1. Pre-check: every `t<N>.md` done; every `handoff-t<N>.md` exists.
2. `cumaru flow plans/<PLAN-ID>/delta-draft.md create` from `templates/delta-draft.md` (`status: draft`).
3. Body — proposed changes to `coverage/` per area touched (`### Added / Modified / Removed Scenarios`, `### Levels / Gaps changed`), or `> No coverage change required — <rationale>.`
4. **Stop.** Do not edit `coverage/` directly — the Lead validates + finalizes during `cumaru-archive`.

## Recipe: ready for archive

Verify `delta-draft.md` exists (`status: draft`), every case done + handoff present, then **hand off to [`cumaru-archive`](../cumaru-archive/SKILL.md)**. This skill does not perform the archive.

## What this skill does NOT do

- **Archive** — `cumaru-archive`. **Coverage authoring** — `cumaru-coverage` (creates the `scope:` areas). **Intake / explore** — `cumaru-intake`, `cumaru-explore`. **Conventions** — `standards/` (referenced, never restated).

## Patterns

| User says | You do |
|---|---|
| "Start a campaign for AAA-1234" | Tracker-backed bootstrap → confirm scope → create plan + maybe T1 → verify with `cumaru tree plans --rows` |
| "Nova campanha pra cobrir o checkout" | Slug-based bootstrap → propose slug → full body (incl. test strategy) |
| "Add case T3 to AAA-1234" | Add-case recipe → write t3.md (Author/Verify) → update DAG → run `cumaru tree` |
| "Write the handoff for T2" | Handoff recipe (Dev) → record scenarios + flakiness check → flip status |
| "Draft the delta for AAA-1234" | Delta-draft recipe (Dev) → verify cases done → propose coverage changes |
| "Archive this campaign" | Verify state → hand off to `cumaru-archive` |

Use `cumaru tag get/set` (CLI) for `plans/index.md`; pair with `cumaru-archive`, `cumaru-coverage`, `cumaru-doctor`.
