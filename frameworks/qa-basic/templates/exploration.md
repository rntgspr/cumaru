---
human_revised: false
generated: false
status: idea | considering | promoted | dropped
apps: [unit] | [integration] | [e2e] | [all]
summary: <one-line summary, used in exploring/index.md>
---

# <Charter title>

## Charter

The mission — what to explore and why, in plain language. A session-based testing charter: a focused area, a time box, and a perspective ("explore X with Y to discover Z").

## Context

Background relevant to the session: the feature under test, links to related coverage/plans, what triggered the charter (a risky change, a recurring incident, a hunch).

## Heuristics / areas to probe

- The angles to attack: boundaries, error paths, concurrency, flaky network, unusual input, state transitions. Free-form — this is not a spec.

## Findings

_Running notes during the session._

- <observation> → **bug** (log in tracker → `intake/<KEY>`) | **coverage gap** (→ a campaign) | **note**.

## Promotion / drop criteria

- What would make you promote this to `plans/<PLAN-ID>/` (a campaign to add coverage)?
- What would make you drop it?
