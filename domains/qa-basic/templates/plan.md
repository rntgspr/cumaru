---
human_revised: false
key: <KEY>                 # optional — omit for slug-based campaigns
type: "feature | bug | regression | task   # optional — the tracker issuetype"
scope:
  - <area>                 # paths under coverage/ this campaign touches
  - <area>/<subarea>
status: "drafting | in-progress | blocked | done"
summary: <one-line summary, used by cumaru tree>
apps: "[unit] | [integration] | [e2e] | [unit, e2e] | [all]   # test levels this campaign authors at"
aux: []
---

# <Campaign title — short, descriptive>

<!-- ===== Slug-based campaigns (no tracker key) ===== -->
<!-- Include Overview + Acceptance Criteria only for slug-based campaigns. Tracker-
     backed campaigns defer them to intake/<KEY>/index.md and do not repeat them. -->

## Overview

What this campaign verifies and why. 1-3 paragraphs.

## Acceptance Criteria (EARS / RFC 2119)

Pick one dominant style for this section: EARS for event/state behavior; RFC 2119 for constraints.

- WHEN <trigger> THE SYSTEM SHALL <observable response>.
- The <resource> MUST <behavior>.

<!-- ===== End slug-only sections ===== -->

## Test Strategy

Which levels this campaign covers and **why** — the pyramid rationale. What is verified at `unit` vs `integration` vs `e2e`, and what is deliberately **not** automated (and why). Reference the relevant `standards/` (mocking, data, gates) instead of restating them.

## Cases / DAG

Cases, ordered by the `depends-on` they touch.

| Task | Title | Level | Status | Depends on |
|------|-------|-------|--------|-----------|
| [T1](t1.md) | Short title | unit | pending | — |
| [T2](t2.md) | Short title | e2e | pending | T1 |

Cases may run in parallel when `depends-on:` is satisfied and their `files:` predictions do not overlap. The Lead verifies before dispatch.

## Scope

The `coverage/<area>` paths this campaign touches. Each is bootstrapped if missing. Name the requirement (`intake/<KEY>`) each area covers — the traceability link.

## Risks / Gaps

- Known coverage gap and why it is acceptable (or the follow-up that closes it).
- A flow that resists automation, and the manual check that compensates.

## Out of scope

- Levels or areas intentionally not addressed by this campaign.
