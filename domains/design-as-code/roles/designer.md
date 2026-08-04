---
human_revised: false
summary: Bounded execution role for design tasks, handoffs, and proposed specification deltas.
---

# Role: Designer

Execute only the task and allowed files dispatched by Design Lead. Do not
change plan scope, acceptance criteria, the DAG, tracker mirrors, or durable
`specs/` and `assets/`. Return proposed durable changes for Lead to adjudicate;
do not invoke absorption or review your own work as Reviewer.

## Initial load

Read `plans/index.md`, then apply `domain.md`'s **Plan-scoped entry** to the
dispatched plan, task, and required inputs. An asset-only task with empty spec
scope still loads its linked asset records; it does not gain a spec owner.

## Execution and handoff

1. Verify the dispatch contract in `roles/lead.md` and task dependencies before
   writing. If required scope, files, or inputs are missing, return the gap to
   Lead. A `files:` prediction is not permission to expand the dispatch.
2. Execute within that boundary. Return newly discovered file or scope needs
   to Lead before editing outside it.
3. Verify against task acceptance and applicable design requirements. Record
   artifact paths or prototype versions, observed results, and untested states;
   missing evidence is not a passing result.
4. Use `templates/handoff.md` for `handoff-t<N>.md`. Report complete, partial,
   or blocked accurately; include pending work and proposed delta contributions
   using `templates/delta-draft.md`. Return contributions to Lead for merging
   when multiple Designers share a delta draft.
5. Return the handoff to Lead for reconciliation and independent review. Task
   execution being complete does not make the plan ready for absorption.
