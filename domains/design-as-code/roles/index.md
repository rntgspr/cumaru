---
human_revised: false
targets: [meta]
summary: Design role ownership and entry points for planning, bounded execution, and independent review.
---



# Roles

| Role | Contract |
|---|---|
| [Design Lead](lead.md) | Scope, plans, dispatch, review reconciliation, and durable absorption. |
| [Designer](designer.md) | Bounded task execution, evidence, handoffs, and proposed deltas. |
| [Reviewer](reviewer.md) | Independent findings returned to Lead without implementation or durable edits. |

Apply the role routing and authorization boundary in `domain.md` before using
a recipe owned by another role.
