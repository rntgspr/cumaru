---
human_revised: false
key: <KEY>                 # optional — omit for slug-based plans
type: "task | story | bug | spike   # optional — omit for slug-based plans"
epic: <EPIC-ID>            # optional
story: <STORY-ID>          # optional
scope:
  - <area>/<concern>
  - <area>/<subarea>/<concern>
status: "drafting | in-progress | blocked | done"
summary: <one-line summary, used by cumaru tree>
apps: "[<app>] | [<app-a>, <app-b>] | [platform]"
aux: []
---

# <Plan title — short, descriptive>

<!-- ===== Slug-based plans (no tracker key) ===== -->
<!-- Include these two sections only when the plan is slug-based (no `key:` in
     frontmatter). Tracker-backed plans defer Overview and Acceptance Criteria to
     intake/<KEY>.md and do not repeat them here. -->

## Overview

Short description of what the plan addresses and why. 1-3 paragraphs.

## Acceptance Criteria (EARS / RFC 2119)

Pick one dominant style for this section: EARS for event/state behavior; RFC 2119 for constraints.

- WHEN <trigger> THE SYSTEM SHALL <observable response>.
- WHEN <trigger> AND <condition> THE SYSTEM SHALL <observable response>.
- WHILE <state> THE SYSTEM SHALL <observable response>.
- The <resource> MUST <behavior>.

<!-- ===== End slug-only sections ===== -->

## Plan / DAG

| Task | Title | Status | Depends on |
|------|-------|--------|-----------|
| [T1](t1.md) | Short title | pending | — |
| [T2](t2.md) | Short title | pending | T1 |

For multi-app plans, suffix with the app key:

| Task | Title | Status | Depends on |
|------|-------|--------|-----------|
| [T1 (<app-a>)](t1-<app-a>.md) | Short title | pending | — |
| [T1 (<app-b>)](t1-<app-b>.md) | Short title | pending | — |

Tasks may run in parallel when `depends-on:` is satisfied and their `files:` predictions do not overlap. The Lead verifies before dispatch.

## Out of scope

- Items intentionally not addressed by this plan.

## Risks

- Risk and mitigation/note.
