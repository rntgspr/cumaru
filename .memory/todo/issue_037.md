---
name: lead-dev-subagent-delegation
description: Make Lead roles prefer bounded Dev sub-agents for implementing active plan work when available
status: completed
priority: medium
---

# Issue 037: Prefer Dev sub-agents for plan implementation

Lead roles currently permit or mention sub-agent dispatch, but usually frame it
as an optional parallelism optimization. This can leave the Lead implementing
plan tasks directly even when a bounded Dev sub-agent could preserve role
separation, produce the expected handoff, and keep orchestration focused.

## Risk

- Lead agents may bypass the domain's Dev execution contract and lose bounded
  task status, verification, handoff, and delta-draft behavior.
- Treating delegation as parallel-only prevents sequential DAG tasks from being
  delegated one at a time.
- Unbounded delegation may bypass role permissions, safety gates, or user
  confirmation, especially for infrastructure apply work.

## Required invariant

In every domain with a Lead role, the Lead prefers task-scoped sub-agents for
implementing active plan, changeset, or campaign work whenever the runtime
supports them and the task can be bounded. Formal Dev roles are used where they
exist; `sdlc-light` delegates under the Lead's authority without inventing a new
role. Parallel safety controls concurrency, not eligibility for delegation.

## Work

1. Update the `sdlc-full`, `iac-basic`, and `qa-basic` Lead roles to prefer Dev
   sub-agents for bounded implementation tasks, including sequential dispatch.
2. Update the `sdlc-light` Lead role to prefer task-scoped sub-agents while
   preserving its single-role model.
3. Require each dispatch to carry the task contract, scope, dependencies,
   verification, and handoff expectations.
4. Preserve explicit fallback and safety boundaries: direct work is acceptable
   only where the Lead role permits it and delegation is unavailable,
   disproportionate, unsafe to bound, or explicitly declined; delegation never
   transfers approvals or bypasses role restrictions.

## Tests

- Every shipped Lead role states a delegation default and distinguishes
  delegation from parallel execution.
- Dev-role domains name the Dev role; `sdlc-light` explicitly retains its
  single-role model.
- Every Lead role preserves safety, role-permission, and user-confirmation
  boundaries for delegated work.

## References

- `domains/sdlc-full/roles/lead.md`
- `domains/sdlc-light/roles/lead.md`
- `domains/iac-basic/roles/lead.md`
- `domains/qa-basic/roles/lead.md`
- `tests/spec/contracts/documented_contracts_spec.sh`
