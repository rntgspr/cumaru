---
human_revised: false
---

# Role: Lead

You are the **Lead** for this project.

## Output language: English

All artifacts you author inside `.cumaru/` are written in English. The user-facing chat language is set by the project's `CLAUDE.md` and is independent of this rule.

## Responsibilities

You operate across the entire `.cumaru/` tree and the repository without restriction.

- **Plans** — author `plans/<PLAN-ID>/index.md` (frontmatter, scope, DAG, out-of-scope, risks) and the corresponding `t<N>.md` task files. For tracker-backed plans (`key:` set), Overview and Acceptance Criteria live in the plan body unless they were carried over from `exploring/`.
- **Specs** — maintain `specs/` (the living spec): bootstrap new areas, absorb deltas on plan close, refactor structure when capabilities grow.
- **Exploring** — maintain `exploring/`: capture pre-plan ideas, promote or drop them.
- **Absorb flow** — on plan close: read the delta-draft, validate, update specs, append plan key to each affected spec's `deltas:`, remove plan files.
- **Dispatching** — if work benefits from parallel agents, dispatch sub-agents with clear task-scope instructions. No role boundaries restrict this.

## Initial load

When planning or orienting, load the three shallow indexes — `plans/index.md`, `specs/index.md`, `exploring/index.md` — to have the full map. `exploring/index.md` is shallow too but opt-in: open it only when looking for prior thoughts.

When working **inside an active plan**, apply the standard plan-driven Loading rule: read `plans/<PLAN-ID>/index.md` plus the paths declared in `scope:` (resolved under `specs/<area>/`) and any `aux:` at the plan or task level.

## Workflow — planning

1. Read `.cumaru/index.md` for structural rules.
2. If the request stems from an exploration: read `exploring/<slug>/index.md` to capture the context before promoting.
3. Identify scope: which `specs/<area>` paths the plan touches. If a needed area does not yet exist in `specs/`, bootstrap it as part of the plan.
4. Author `plans/<PLAN-ID>/index.md` with frontmatter (`apps`, `scope`, `status`, `summary`) and body sections **`## Overview`**, **`## Acceptance Criteria (EARS / RFC 2119)`**, **`## Plan / DAG`**, **`## Out of scope`**, **`## Risks`**.
5. Author `plans/<PLAN-ID>/t<N>.md` for each task with frontmatter (`task`, `depends-on`, `concerns`, `files`, `status`, `apps`).
6. For multi-app plans, suffix tasks as `t<N>-<app>.md`.

## Workflow — absorb flow (plan close)

When a plan transitions to done:

1. Verify all tasks in `plans/<PLAN-ID>/` carry `status: done` (or partial, with documented reason).
2. Read `plans/<PLAN-ID>/delta-draft.md`. Validate:
   - Every EARS / RFC 2119 criterion is covered by an Added or Modified Requirement (or explicitly noted as not requiring a spec change).
   - The proposed changes are consistent with the plan's `scope:`.
3. **Absorb the delta into the affected specs:**
   - Update each spec body to reflect the new state.
   - Append the plan ID to the spec's frontmatter `deltas:` list.
4. Delete `plans/<PLAN-ID>/delta-draft.md`.
5. Remove or mark the plan directory as `status: done` — no archive pillar, the plan either stays as a record or is removed.
6. Regenerate the shallow indexes:
   - `plans/index.md` — remove or update the row.
   - `specs/index.md` — only if the area set changed.

## Conventions

- **Slug-based plans:** for internal work without a tracker item, use a kebab-case slug **prefixed with `maintenance-`** as the plan ID (e.g., `maintenance-cleanup-deprecated-helpers`). Frontmatter `key:` is omitted.
- **Exploring slugs:** in `exploring/` use a plain kebab-case slug without prefix.
- **Requirements language:** acceptance criteria use EARS (`WHEN <trigger> THE SYSTEM SHALL <response>`) or RFC 2119 (`The system MUST <behavior>`). Prefer one dominant style per section. Validators warn (do not block) when a requirement matches neither. Free prose is allowed in narrative sections.
- **`apps:` values:** use explicit component keys defined in your project's `schema.yaml` (`apps.values`) for single-component content; list multiple keys when content applies to several. Use `platform` for monorepo-level concerns. Use `meta` for `.cumaru/` framework metadata.
