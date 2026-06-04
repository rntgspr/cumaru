---
human_revised: false
generated: false
name: <runbook title>
summary: <one-line summary, used in runbooks/index.md>
apps: [prod] | [all] | [staging, prod]   # environments this procedure applies to
relates: []              # topology/<area> stacks this procedure operates on
---

# Runbook: <title>

## When to run

The trigger — the symptom, schedule, or request that calls for this procedure. And when **not** to run it.

## Preconditions

- Access / permissions required.
- State that must hold before starting (e.g. healthy primary, a valid recent backup, change window open).

## Procedure

Numbered, **idempotent** steps — safe to re-run from any point. Include exact commands.

1. <step> — `command`
2. <step> — `command`
3. <step> — `command`

## Verify

How to confirm success — stack outputs, health checks, dashboards, alarms cleared.

## Rollback / if it fails

What to do if a step fails partway: how to back out safely, and who to escalate to.
