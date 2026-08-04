---
human_revised: false
version: 1
name: cumaru-plan
description: Create and advance design plans through bounded Designer execution, independent review, handoffs, and Lead readiness checks.
summary: Create and advance design plans through bounded Designer execution, independent review, handoffs, and Lead readiness checks.
---

# Cumaru plan — design delivery

Read `.cumaru/domain.md` and apply its role routing boundary. Design Lead owns
planning, dispatch, status reconciliation, delta consolidation, and readiness.
Designer uses the handoff recipe only within a bounded dispatch; Reviewer
returns findings under `roles/reviewer.md` without editing the plan.
Load the active role's initial context. Invocation never silently switches roles.

## Create a plan

1. For tracker-backed work, read `intake/<KEY>.md`. If absent or materially
   outdated, use `cumaru-intake` first. Resolve pending acceptance decisions.
   The brief is the sole local Overview and Acceptance Criteria; use `<KEY>`
   as the plan ID. Selected concepts use `cumaru-concept` promotion first.
2. Internal maintenance without a tracker uses `maintenance-<kebab-slug>`;
   omit `key:` and `type:` and keep the acceptance contract in the plan. Do not
   invent a tracker item or use maintenance to bypass concept promotion.
3. Discover scope with `cumaru tree specs --rows`; select relevant summaries
   and recurse only into matching areas. Confirm scope using the user's
   existing decisions; propose any missing owner through `cumaru-specs`.
4. Use `cumaru fs plans/<PLAN-ID> create` and
   `cumaru fs plans/<PLAN-ID>/index.md create`, then fill `templates/plan.md`.
   Follow its matching acceptance-source variant and map every criterion to
   tasks and required evidence. Link selected concepts and research directly;
   `aux:` is for plan-local supporting files.
5. Run `cumaru tree plans --rows` and `cumaru doctor` after authoring.

## Add a task

Choose the next unused task number. Create `plans/<PLAN-ID>/t<N>.md` through
`cumaru fs` and fill `templates/task.md`. Use the canonical template for
bounded writes, criterion references, applicable design verification, and done
conditions. Add its row and dependencies to the plan DAG and coverage mapping.
Run `cumaru doctor`.

## Execute and review

1. Lead dispatches ready tasks using `roles/lead.md`. Parallel work requires
   satisfied dependencies and non-overlapping allowed writes.
2. Designer returns results in `plans/<PLAN-ID>/handoff-t<N>.md` following
   `templates/handoff.md`, with proposed contributions using
   `templates/delta-draft.md`. Keep shared plan and delta consolidation under Lead.
3. Lead reconciles task status and DAG from evidence. Execution being `done`
   does not mean review is complete. Obtain independent Reviewer findings under
   `roles/reviewer.md`; retain the report and dispositions in the handoff.
4. Dispatch corrections and obtain rechecks of the delivered revision. Follow
   the Lead role's readiness rules when evidence or independent review is missing.

## Draft the delta and prepare absorption

1. Require completed tasks and handoffs with verification for every criterion
   in the plan coverage mapping. Keep missing or failing evidence open.
2. Create `plans/<PLAN-ID>/delta-draft.md` using `templates/delta-draft.md`;
   consolidate proposed spec and asset changes with their reviewed evidence.
3. Apply `roles/lead.md` readiness checks, including independent review of the
   delivered revision and proposed delta. Reconcile each criterion through a
   durable change or explicit no-change rationale. Do not edit specs yet.
4. Hand off to `cumaru-absorb` only when no unresolved findings or missing
   required verification remain. Run `cumaru doctor` after plan edits.

Use `cumaru tree` for navigation; do not write structural inventories into
pillar tags. Templates are the canonical body and metadata contracts.
