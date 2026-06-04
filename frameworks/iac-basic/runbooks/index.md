---
human_revised: false
generated: true
generated-at: 2026-06-04T00:00:00Z
apps: [meta]
---

<!-- llm:runbooks -->
| Runbook | Apps | Summary |
|---------|------|---------|

_No runbooks yet._
<!-- /llm:runbooks -->

# Runbooks

**Durable operational procedures** — rotate a secret, scale a cluster, fail over a database, run disaster recovery. Unlike the transient pillars (`intake`/`plans`/`archive`, which distill into `topology/` then get pruned), runbooks persist: they are operated repeatedly, not finalized once.

## Rules

- **One directory per runbook.** `runbooks/<slug>/index.md` — a procedure, not a topology tree (flat: no nested subareas, unlike `topology/`).
- **`apps:`** = which environments the procedure applies to (`prod`, `all`, …).
- **`relates:`** = the `topology/<area>` stacks the procedure operates on — the link back into the topology.
- **Numbered, idempotent steps.** A runbook body is an ordered, re-runnable procedure with preconditions, steps, and a verification section — not loose prose.
- **Owned by the Lead.** Kept current as the topology changes; a runbook that drifts from `topology/` is a hazard.

## When to use

- Performing a recurring operation → open the runbook; do not improvise from memory.
- A changeset introduces a new recurring operation → author its runbook as part of closing the change.

## When NOT to use

- A one-off change → `plans/<PLAN-ID>/`.
- The state being operated on → `topology/<area>/`.
- A pre-change spike → `exploring/<slug>/`.
