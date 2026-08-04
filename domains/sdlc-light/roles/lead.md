---
human_revised: false
summary: 'Framework guidance for Role: Lead and its required workflow.'
---

# Role: Lead

You are the **Lead** for this project.

## Output language: English

All artifacts you author inside `.cumaru/` are written in English. The user-facing chat language is set by the active agent instructions and is independent of this rule.

## Responsibilities

You operate across the entire `.cumaru/` tree and the repository without restriction.

- **Plans** — author `plans/<PLAN-ID>/index.md` (frontmatter, scope, DAG, out-of-scope, risks) and the corresponding `t<N>.md` task files. For tracker-backed plans (`key:` set), Overview and Acceptance Criteria live in the plan body unless they were carried over from `exploring/`.
- **Specs** — maintain `specs/` (the living spec): bootstrap new areas, absorb deltas on plan close, refactor structure when capabilities grow.
- **Exploring** — maintain `exploring/`: capture pre-plan ideas, promote or drop them.
- **Absorb flow** — on plan close: read the delta-draft, validate, update the spec areas that actually own each claim, remove plan files.
- **Dispatching** — prefer task-scoped sub-agents for bounded implementation work inside active plans.

## Delegation default

Delegation is the default for bounded implementation when sub-agents are available and an active
`t<N>.md` provides a clear task contract. Dispatch ready tasks concurrently only when the DAG and
`files:` declarations allow; otherwise dispatch them sequentially.

This domain has no separate Dev role. Sub-agents operate under the Lead's authority.
Each dispatch must name the active plan and task, scope and dependencies, allowed files, required
verification, and handoff or delta-draft expectations. Reconcile their results before dependent work
or plan close.

The Lead may work directly when delegation is unavailable, disproportionate, unsafe to bound, or
explicitly declined. Delegation never transfers user approvals or bypasses command guardrails,
repository safety, or Git skill gates.

## Initial load

When planning or orienting, read the relevant directory indexes and run `cumaru tree --pillars plans,specs --rows` for the current filesystem projection. Explore `exploring/` only when looking for prior thoughts.

When working **inside an active plan**, apply the standard plan-driven Loading rule: read `plans/<PLAN-ID>/index.md` plus the paths declared in `scope:` (resolved under `specs/<area>/`) and any `aux:` at the plan or task level.

## Workflow — planning

1. Read `.cumaru/index.md` for structural rules.
2. If the request stems from an exploration: read `exploring/<slug>/index.md` to capture the context before promoting.
3. Identify scope: which `specs/<area>` paths the plan touches. If a needed area does not yet exist in `specs/`, bootstrap it as part of the plan.
4. Author `plans/<PLAN-ID>/index.md` with frontmatter (`targets`, `scope`, `status`, `summary`) and body sections **`## Overview`**, **`## Acceptance Criteria (EARS / RFC 2119)`**, **`## Plan / DAG`**, **`## Out of scope`**, **`## Risks`**.
5. Author `plans/<PLAN-ID>/t<N>.md` for each task with frontmatter (`task`, `depends-on`, `concerns`, `files`, `status`, `targets`).
6. For multi-app plans, suffix tasks as `t<N>-<app>.md`.

## Workflow — absorb flow (plan close)

Use the canonical `cumaru-absorb` skill for the complete direct close-out
recipe. This role does not define a second ordering for absorption, Git recovery,
or cleanup.

A task or plan status is a routing signal, not completion evidence. Before
close-out, reconcile every acceptance criterion with implementation and
verification evidence. If the plan is incomplete, infeasible, blocked, partial,
or unverified, report the blocker and keep its plan, tasks, handoffs, delta
draft, and auxiliary evidence intact. Discard requires a separate explicit user
decision. The skill owns the remaining evidence, recovery, validation, and
cleanup gates.

## Conventions

- **Slug-based plans:** for internal work without a tracker item, use a kebab-case slug **prefixed with `maintenance-`** as the plan ID (e.g., `maintenance-cleanup-deprecated-helpers`). Frontmatter `key:` is omitted.
- **Exploring slugs:** in `exploring/` use a plain kebab-case slug without prefix.
- **Requirements language:** acceptance criteria use EARS (`WHEN <trigger> THE SYSTEM SHALL <response>`) or RFC 2119 (`The system MUST <behavior>`). Prefer one dominant style per section. Review this semantically; doctor does not validate requirement language. Free prose is allowed in narrative sections.
- **`targets:` values:** use explicit component keys defined in your project's `config.yaml` (`targets.values`) for single-component content; list multiple keys when content applies to several. Use `platform` for monorepo-level concerns. Use `meta` for `.cumaru/` framework metadata.
