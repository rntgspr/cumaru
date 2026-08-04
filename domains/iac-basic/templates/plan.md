---
human_revised: false
key: <KEY>                 # optional — omit for slug-based changes
type: "change | incident | task   # optional — the tracker issuetype"
scope:
  - <area>                 # paths under topology/ this change touches
  - <area>/<subarea>
status: "drafting | in-progress | blocked | done"
summary: <one-line summary, used by cumaru tree>
apps: "[dev] | [staging] | [prod] | [dev, staging] | [all]   # environments this change targets"
aux: []
---

# <Change title — short, descriptive>

<!-- ===== Slug-based changes (no tracker key) ===== -->
<!-- Include Overview + Acceptance Criteria only for slug-based changes. Tracker-
     backed changes defer them to intake/<KEY>/index.md and do not repeat them. -->

## Overview

What this change does to the infrastructure and why. 1-3 paragraphs.

## Acceptance Criteria (EARS / RFC 2119)

Pick one dominant style for this section: EARS for event/state behavior; RFC 2119 for constraints.

- WHEN <trigger> THE SYSTEM SHALL <observable response>.
- The <resource> MUST <behavior>.

<!-- ===== End slug-only sections ===== -->

## Plan / DAG

Apply steps, ordered by the topology `depends-on` they touch.

| Task | Title | Status | Depends on |
|------|-------|--------|-----------|
| [T1](t1.md) | Short title | pending | — |
| [T2](t2.md) | Short title | pending | T1 |

Tasks may run in parallel when `depends-on:` is satisfied and their `files:` predictions do not overlap. The Lead verifies before dispatch.

## Blast radius

What this change can affect if it goes wrong, and across which environments. Name the stacks (`topology/<area>`) and downstream consumers in scope. Call out anything **irreversible** (data deletion, CIDR change, DNS cutover, force-replace).

## Rollback

The reversal procedure, step by step — or an explicit statement that there is none and why. State this **before** apply, not after. Link a `runbooks/<slug>/` if a standing rollback procedure exists.

## Promotion path

The environment order this change rolls through, with the gate between each.

| Environment | Gate to promote |
|-------------|-----------------|
| dev | applied + smoke-tested |
| staging | soak + review |
| prod | change window + approval |

## Out of scope

- Items intentionally not addressed by this change.

## Risks

- Risk and mitigation/note.
